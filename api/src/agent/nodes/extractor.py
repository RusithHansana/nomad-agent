from __future__ import annotations

import asyncio
import json
import logging
import re
import time
from collections.abc import Awaitable, Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from src.agent.state import AgentState, append_event_to_buffer, get_event_buffer
from src.config import get_settings
from src.models.events import ThoughtLogData, ThoughtLogEvent

logger = logging.getLogger(__name__)

VENUE_TASK_NAMES = {"local research", "event checking", "interest deep-dive"}
MAX_RAW_CONTENT_CHARS = 3000
MAX_CONTENT_CHARS = 800
MAX_VENUES_PER_TASK = 8
EXTRACTION_MODEL = "gemini-3-flash-preview"

# Patterns for stripping HTML noise from raw_content
_STRIP_BLOCK_TAGS_RE = re.compile(
    r"<(script|style|nav|footer|header|aside|noscript|iframe)[^>]*>.*?</\1>",
    re.DOTALL | re.IGNORECASE,
)
_STRIP_ALL_TAGS_RE = re.compile(r"<[^>]+>")
_STRIP_URLS_RE = re.compile(r"https?://\S+")
_STRIP_MD_IMAGES_RE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
_STRIP_MD_LINKS_RE = re.compile(r"\[([^\]]*?)\]\([^)]*\)")
_STRIP_EMOJI_RE = re.compile(
    r"[\U0001F300-\U0001F9FF\U00002600-\U000027BF\U0000FE00-\U0000FE0F"
    r"\U0000200D\U00002702-\U000027B0]+",
)
_STRIP_MD_NAV_RE = re.compile(r"^\s*\*\s*\[.*?\]\(.*?\)\s*$", re.MULTILINE)
_COLLAPSE_WHITESPACE_RE = re.compile(r"[ \t]+")
_COLLAPSE_NEWLINES_RE = re.compile(r"\n{3,}")
_BOILERPLATE_RE = re.compile(
    r"(?:cookie|sign\s*up|log\s*in|download\s+(?:our|the)\s+app|"
    r"subscribe|newsletter|privacy\s+policy|terms\s+of\s+(?:use|service))",
    re.IGNORECASE,
)

EXTRACTION_PROMPT = (
    "You are a travel data extraction assistant. "
    "Given web search results about places in {destination}, "
    "extract structured venue information.\n\n"
    "For each REAL venue, restaurant, attraction, or event mentioned, extract:\n"
    "- name: actual venue name in English (translate/transliterate non-English names)\n"
    '- venue_type: one of "restaurant","attraction","nature","event","tour"\n'
    "- address: street address or neighborhood (NOT URLs)\n"
    "- latitude: decimal latitude if determinable, else null\n"
    "- longitude: decimal longitude if determinable, else null\n"
    "- opening_hours: list of strings e.g. [\"Mon-Fri 9:00-17:00\"] if mentioned, else null\n"
    "- rating: numeric /5.0 if mentioned, else null\n"
    "- price_level: 1-4 (1=budget,2=moderate,3=upscale,4=luxury) if determinable, else null\n"
    "- source_url: exact URL of the search result block where this venue was found\n\n"
    "CRITICAL — Opening Hours:\n"
    "Pay special attention to business hours, operating hours, opening times, and schedules. "
    "Extract these even if in informal formats like '11am-10pm daily' or "
    "'Lunch: 11:00-15:00, Dinner: 17:00-23:00'. "
    "If hours appear ANYWHERE in the source text, you MUST extract them.\n\n"
    "Rules:\n"
    "- Extract ONLY real, named venues — skip aggregator pages and listicle headers\n"
    "- A single search result may describe multiple venues — extract all with same source_url\n"
    "- For lat/lng, use your knowledge of well-known venues if not in text\n"
    "- Venue names must be in English\n"
    "- Classify venue_type by what the venue IS, not where found\n"
    "- Only extract venues relevant to a trip about \"{destination}\"\n"
    "- Maximum {max_venues} venues\n\n"
    "Search results:\n"
    "{results_block}\n\n"
    "Respond with ONLY a compact minified JSON array. "
    "No whitespace, newlines, indentation, code fences, or explanation."
)

LLM_ONLY_VENUE_PROMPT = (
    "You are a travel itinerary planner. "
    "Suggest realistic travel venues for a trip to {destination} lasting {duration_days} day(s). "
    "The traveler's interests include: {categories}.\n\n"
    "For each venue, provide:\n"
    "- name: venue name in English\n"
    '- venue_type: one of "restaurant","attraction","nature","event","tour"\n'
    "- address: neighborhood or area (NOT URLs)\n"
    "- latitude: decimal latitude using your knowledge, else null\n"
    "- longitude: decimal longitude using your knowledge, else null\n"
    "- opening_hours: typical hours if known, else null\n"
    "- rating: estimated rating /5.0 if known, else null\n"
    "- price_level: 1-4 (1=budget,2=moderate,3=upscale,4=luxury) if known, else null\n"
    "- source_url: null (no web source available)\n\n"
    "Rules:\n"
    "- Suggest ONLY real, named venues that exist in {destination}\n"
    "- Venue names must be in English\n"
    "- Maximum {max_venues} venues total\n"
    "- Distribute venues across the traveler's interest categories\n\n"
    "Respond with ONLY a compact minified JSON array. "
    "No whitespace, newlines, indentation, code fences, or explanation."
)


def _clean_raw_content(text: str) -> str:
    """Strip HTML and markdown noise from raw page content, preserving informational text."""
    if not text:
        return text

    # Remove entire block-level noise elements
    cleaned = _STRIP_BLOCK_TAGS_RE.sub("", text)
    # Strip remaining HTML tags but keep their text content
    cleaned = _STRIP_ALL_TAGS_RE.sub(" ", cleaned)

    # Remove markdown image references (carry zero venue info)
    cleaned = _STRIP_MD_IMAGES_RE.sub("", cleaned)
    # Convert markdown links to just their text (drop the URL target)
    cleaned = _STRIP_MD_LINKS_RE.sub(r"\1", cleaned)
    # Remove markdown navigation lists (e.g. breadcrumb patterns)
    cleaned = _STRIP_MD_NAV_RE.sub("", cleaned)
    # Remove decorative emoji
    cleaned = _STRIP_EMOJI_RE.sub("", cleaned)
    # Remove inline URLs (image links, hrefs that leaked through)
    cleaned = _STRIP_URLS_RE.sub("", cleaned)

    # Remove lines that are mostly boilerplate
    lines = cleaned.split("\n")
    filtered: list[str] = []
    for line in lines:
        stripped = line.strip()
        if not stripped:
            continue
        # Drop short boilerplate lines
        if len(stripped) < 80 and _BOILERPLATE_RE.search(stripped):
            continue
        filtered.append(stripped)

    cleaned = "\n".join(filtered)
    # Collapse whitespace
    cleaned = _COLLAPSE_WHITESPACE_RE.sub(" ", cleaned)
    cleaned = _COLLAPSE_NEWLINES_RE.sub("\n\n", cleaned)
    return cleaned.strip()


def _minify_prompt(prompt: str) -> str:
    """Compress whitespace in the prompt to reduce token count."""
    # Collapse runs of spaces/tabs (but preserve single newlines for structure)
    minified = re.sub(r"[ \t]+", " ", prompt)
    # Collapse 3+ newlines to 2
    minified = re.sub(r"\n{3,}", "\n\n", minified)
    # Strip trailing spaces on each line
    minified = re.sub(r" +\n", "\n", minified)
    return minified.strip()


def _format_results_block_for_task(
    task_name: str,
    entries: list[dict[str, object]],
) -> tuple[str, list[dict[str, object]]]:
    """Build formatted results text for a single task."""
    if not isinstance(entries, list):
        return "", []

    task_lines: list[str] = [f"--- Task: {task_name} ---"]
    valid_entries: list[dict[str, object]] = []

    for entry in entries:
        if not isinstance(entry, dict):
            continue

        title = str(entry.get("title") or "").strip()
        url = str(entry.get("url") or "").strip()
        content = str(entry.get("content") or "").strip()[:MAX_CONTENT_CHARS]
        raw_content = _clean_raw_content(
            str(entry.get("raw_content") or "").strip()
        )[:MAX_RAW_CONTENT_CHARS]

        if not title and not content and not raw_content:
            continue

        lines = [f"Title: {title}"]
        if url:
            lines.append(f"URL: {url}")
        if content:
            lines.append(f"Content: {content}")
        if raw_content:
            lines.append(f"Raw Content: {raw_content}")
        task_lines.append("\n".join(lines))
        valid_entries.append(entry)

    if len(task_lines) <= 1:
        return "", valid_entries

    return "\n\n".join(task_lines), valid_entries


def _build_extraction_prompt(
    destination: str, results_block: str, max_venues: int = MAX_VENUES_PER_TASK,
) -> str:
    prompt = EXTRACTION_PROMPT.format(
        destination=destination,
        max_venues=max_venues,
        results_block=results_block,
    )
    return _minify_prompt(prompt)


def _parse_extraction_response(response_text: str) -> list[dict[str, Any]]:
    """Parse LLM response into a list of venue dicts.

    Includes a fallback for truncated JSON: if the response starts with
    a valid array but is cut off mid-stream (e.g. due to max_output_tokens),
    we attempt to close the array at the last complete object.
    """
    cleaned = response_text.strip()

    # Strip markdown code fences if present
    if cleaned.startswith("```"):
        first_newline = cleaned.find("\n")
        if first_newline != -1:
            cleaned = cleaned[first_newline + 1 :]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    parsed = _try_parse_json_array(cleaned)
    if parsed is None:
        return []

    venues: list[dict[str, Any]] = []
    for item in parsed:
        if isinstance(item, dict) and item.get("name"):
            venues.append(item)

    return venues[:MAX_VENUES_PER_TASK]


def _try_parse_json_array(text: str) -> list[Any] | None:
    """Try to parse a JSON array, with fallback for truncated responses."""
    # Happy path — full, valid JSON
    try:
        result = json.loads(text)
        return result if isinstance(result, list) else None
    except json.JSONDecodeError:
        pass

    # Truncation recovery: find the last complete object (ends with "}")
    # and close the array.
    if not text.startswith("["):
        return None

    last_brace = text.rfind("}")
    if last_brace == -1:
        return None

    candidate = text[: last_brace + 1].rstrip().rstrip(",") + "]"
    try:
        result = json.loads(candidate)
        if isinstance(result, list):
            logger.info(
                "Recovered %d venue(s) from truncated extraction response",
                len(result),
            )
            return result
    except json.JSONDecodeError:
        pass

    return None


def _enrich_venues_with_source(
    extracted_venues: list[dict[str, Any]],
    source_map: dict[str, list[dict[str, object]]],
) -> dict[str, list[dict[str, object]]]:
    """Distribute extracted venues back into task-keyed results with source URLs preserved."""
    url_info: dict[str, dict[str, Any]] = {}
    fallback_url = None
    fallback_task = None

    for task_name, entries in source_map.items():
        if fallback_task is None:
            fallback_task = task_name
        for entry in entries:
            if isinstance(entry, dict):
                url = str(entry.get("url") or "").strip()
                if url and url not in url_info:
                    url_info[url] = {
                        "degraded": bool(entry.get("_degraded_unverified")),
                        "task_name": task_name
                    }
                    if fallback_url is None:
                        fallback_url = url

    enriched_results: dict[str, list[dict[str, object]]] = {name: [] for name in source_map}
    if fallback_task is None:
        return enriched_results

    for venue in extracted_venues:
        venue_copy = dict(venue)
        source_url = str(venue_copy.get("source_url") or "").strip()

        if not source_url or source_url not in url_info:
            source_url = fallback_url
            venue_copy["source_url"] = source_url

        if source_url and source_url in url_info:
            info = url_info[source_url]
            if info["degraded"]:
                venue_copy["_degraded_unverified"] = True
            enriched_results[info["task_name"]].append(venue_copy)
        else:
            enriched_results[fallback_task].append(venue_copy)

    return enriched_results


def _dump_to_markdown(data: dict[str, Any], filename_prefix: str) -> None:
    """Dump structured data to a markdown file for debugging."""
    try:
        # Get project root (assuming we are in api/src/agent/nodes/)
        # Path(__file__) is .../api/src/agent/nodes/extractor.py
        # .parent.parent.parent.parent is .../api/
        project_root = Path(__file__).resolve().parent.parent.parent.parent
        dump_dir = project_root / "debug_dumps"
        dump_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = dump_dir / f"{filename_prefix}_{timestamp}.md"

        content = [
            f"# Debug Dump: {filename_prefix}",
            f"Generated: {datetime.now().isoformat()}",
            "",
        ]

        for task_name, items in data.items():
            content.append(f"## Task: {task_name}")
            if not isinstance(items, list):
                content.append(f"Data: {items}")
                continue

            for idx, item in enumerate(items):
                content.append(f"### Item {idx + 1}")
                content.append("```json")
                content.append(json.dumps(item, indent=2))
                content.append("```")
                content.append("")

        filepath.write_text("\n".join(content))
        logger.info(f"Dumped debug data to {filepath}")
    except Exception:
        logger.exception(f"Failed to dump debug data for {filename_prefix}")


def _dump_raw_response(response_text: str, filename_prefix: str) -> None:
    """Dump raw LLM response string to a file for debugging."""
    try:
        project_root = Path(__file__).resolve().parent.parent.parent.parent
        dump_dir = project_root / "debug_dumps"
        dump_dir.mkdir(parents=True, exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filepath = dump_dir / f"{filename_prefix}_{timestamp}.json"

        filepath.write_text(response_text)
        logger.info(f"Dumped raw response to {filepath}")
    except Exception:
        logger.exception(f"Failed to dump raw response for {filename_prefix}")


async def _call_gemini(prompt: str) -> str | None:
    """Call LLM for venue extraction. Returns response text or None on failure."""
    settings = get_settings()
    if not settings.gemini_api_key:
        logger.warning("Gemini API key not configured — skipping extraction")
        return None

    try:
        from google import genai

        client = genai.Client(api_key=settings.gemini_api_key)
        response = await client.aio.models.generate_content(
            model=EXTRACTION_MODEL,
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.1,
                max_output_tokens=8192,
                response_mime_type="application/json",
            ),
        )
        return response.text
    except Exception:
        logger.exception("Gemini extraction call failed")
        return None


async def _generate_llm_only_venues(
    destination: str,
    categories: list[str],
    duration_days: int,
    llm_caller: Callable[[str], Awaitable[str | None]] | None = None,
) -> list[dict[str, Any]]:
    """Generate venue suggestions using Gemini when Tavily is fully unavailable."""
    categories_str = ", ".join(categories) if categories else "general sightseeing"
    max_venues = min(MAX_VENUES_PER_TASK * 3, 24)  # up to 24 for LLM-only mode
    prompt = LLM_ONLY_VENUE_PROMPT.format(
        destination=destination,
        duration_days=duration_days,
        categories=categories_str,
        max_venues=max_venues,
    )
    prompt = _minify_prompt(prompt)

    if llm_caller is not None:
        response_text = await llm_caller(prompt)
    else:
        response_text = await _call_gemini(prompt)

    if response_text is None:
        logger.warning("LLM-only venue generation failed for destination '%s'", destination)
        return []

    try:
        venues = _parse_extraction_response(response_text)
    except (json.JSONDecodeError, ValueError):
        logger.warning(
            "Failed to parse LLM-only venue response for '%s'. Raw: %s",
            destination,
            response_text[:500] if response_text else "<empty>",
        )
        return []

    # Mark all LLM-only venues as degraded unverified
    degraded_venues: list[dict[str, Any]] = []
    for venue in venues:
        venue_copy = dict(venue)
        venue_copy["_degraded_unverified"] = True
        venue_copy["source_url"] = None
        degraded_venues.append(venue_copy)

    logger.info(
        "LLM-only venue generation produced %d venues for '%s'",
        len(degraded_venues), destination,
    )
    return degraded_venues


async def pre_extractor_node(state: AgentState) -> dict[str, Any]:
    """Lightweight node to emit the 'Extracting' event before the heavy LLM work.

    This ensures the UI updates immediately after research ends, avoiding a hang.
    """
    if state.get("error_event") is not None:
        return state

    events, event_cursor, event_base_cursor = get_event_buffer(state)

    events, event_cursor, event_base_cursor = append_event_to_buffer(
        events=events,
        event_cursor=event_cursor,
        event_base_cursor=event_base_cursor,
        payload=ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message="Extracting venue details from search results",
                icon="🔍",
                step="extractor",
            ),
        ).to_payload(),
    )

    return {
        **state,
        "events": events,
        "event_cursor": event_cursor,
        "event_base_cursor": event_base_cursor,
    }


async def _extract_single_task(
    task_name: str,
    entries: list[dict[str, object]],
    destination: str,
    llm_caller: Callable[[str], Awaitable[str | None]] | None,
) -> tuple[str, list[dict[str, object]], list[dict[str, Any]]]:
    """Run extraction for a single task. Returns (task_name, valid_entries, venues)."""
    results_block, valid_entries = _format_results_block_for_task(
        task_name, entries,
    )
    if not results_block.strip():
        return task_name, valid_entries, []

    prompt = _build_extraction_prompt(destination, results_block)

    t0 = time.monotonic()

    if llm_caller is not None:
        response_text = await llm_caller(prompt)
    else:
        response_text = await _call_gemini(prompt)

    elapsed = time.monotonic() - t0

    if response_text:
        _dump_raw_response(
            response_text,
            f"raw_extraction_{task_name.lower().replace(' ', '_')}",
        )

    if response_text is None:
        logger.warning(
            "Extraction call failed for task '%s' after %.1fs — skipping",
            task_name, elapsed,
        )
        return task_name, valid_entries, []

    try:
        task_venues = _parse_extraction_response(response_text)
    except (json.JSONDecodeError, ValueError):
        logger.warning(
            "Failed to parse extraction response for task '%s' "
            "(%.1fs). Raw text (first 2000 chars): %s",
            task_name, elapsed,
            response_text[:2000] if response_text else "<empty>",
        )
        return task_name, valid_entries, []

    logger.info(
        "Extracted %d venues from task '%s' in %.1fs "
        "(prompt: %d chars, response: %d chars)",
        len(task_venues), task_name, elapsed,
        len(prompt), len(response_text),
    )
    return task_name, valid_entries, task_venues


async def extractor_node(
    state: AgentState,
    *,
    llm_caller: Callable[[str], Awaitable[str | None]] | None = None,
) -> dict[str, Any]:
    """Extract structured venue data from raw Tavily results using Gemini.

    When Tavily is fully unavailable (tavily_unavailable=True in state),
    falls back to LLM-only venue generation using Gemini.

    Processes each venue task independently and in parallel using
    asyncio.gather to minimize wall-clock time. Results are aggregated
    and enriched with source URL metadata before being merged back
    into state.
    """
    if state.get("error_event") is not None:
        return state

    events, event_cursor, event_base_cursor = get_event_buffer(state)

    raw_task_results = state.get("task_results", {})
    task_results = dict(raw_task_results) if isinstance(raw_task_results, dict) else {}
    destination = str(state.get("destination", "")).strip() or "Unknown Destination"
    tavily_unavailable = bool(state.get("tavily_unavailable", False))

    # ── LLM-only fallback path ────────────────────────────────────────────
    if tavily_unavailable:
        events, event_cursor, event_base_cursor = append_event_to_buffer(
            events=events,
            event_cursor=event_cursor,
            event_base_cursor=event_base_cursor,
            payload=ThoughtLogEvent(
                timestamp=datetime.now(UTC).isoformat(),
                data=ThoughtLogData(
                    message="Generating AI-only suggestions (verification service unavailable)",
                    icon="🤖",
                    step="extractor",
                ),
            ).to_payload(),
        )
        raw_categories = state.get("interest_categories", [])
        categories: list[str] = list(raw_categories) if isinstance(raw_categories, list) else []
        duration_days = max(1, int(state.get("duration_days") or 1))

        llm_venues = await _generate_llm_only_venues(
            destination=destination,
            categories=categories,
            duration_days=duration_days,
            llm_caller=llm_caller,
        )

        # Place all LLM-only venues under the "local research" task key
        # so the compiler picks them up via _is_venue_task()
        llm_task_results = {"local research": llm_venues}

        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
            "task_results": {**task_results, **llm_task_results},
        }

    # ── Normal Tavily-backed extraction path ──────────────────────────────

    # Identify venue tasks to process
    venue_tasks = [
        (name, entries)
        for name, entries in task_results.items()
        if isinstance(name, str)
        and name.strip().lower() in VENUE_TASK_NAMES
        and isinstance(entries, list)
    ]

    if not venue_tasks:
        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
        }

    # Log before extraction
    _dump_to_markdown(task_results, "before_extraction")

    # Emit a single progress event before the parallel batch
    task_names_str = ", ".join(name for name, _ in venue_tasks)
    events, event_cursor, event_base_cursor = append_event_to_buffer(
        events=events,
        event_cursor=event_cursor,
        event_base_cursor=event_base_cursor,
        payload=ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message=f"Analyzing {task_names_str}",
                icon="🧠",
                step="extractor",
            ),
        ).to_payload(),
    )

    # Fire all LLM extraction calls in parallel
    t0_all = time.monotonic()
    extraction_coros = [
        _extract_single_task(task_name, entries, destination, llm_caller)
        for task_name, entries in venue_tasks
    ]
    extraction_results = await asyncio.gather(*extraction_coros, return_exceptions=True)
    elapsed_all = time.monotonic() - t0_all
    logger.info(
        "All %d extraction tasks completed in %.1fs (parallel)",
        len(extraction_coros), elapsed_all,
    )

    # Aggregate results from all parallel tasks
    all_extracted: list[dict[str, Any]] = []
    combined_source_map: dict[str, list[dict[str, object]]] = {}

    for result in extraction_results:
        if isinstance(result, BaseException):
            logger.error("Extraction task raised an exception: %s", result)
            continue
        task_name, valid_entries, task_venues = result
        combined_source_map[task_name] = valid_entries
        all_extracted.extend(task_venues)

    if not all_extracted:
        events, event_cursor, event_base_cursor = append_event_to_buffer(
            events=events,
            event_cursor=event_cursor,
            event_base_cursor=event_base_cursor,
            payload=ThoughtLogEvent(
                timestamp=datetime.now(UTC).isoformat(),
                data=ThoughtLogData(
                    message="Using raw search results (extraction unavailable)",
                    icon="⚠️",
                    step="extractor",
                ),
            ).to_payload(),
        )
        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
        }

    enriched_results = _enrich_venues_with_source(all_extracted, combined_source_map)

    # Log after extraction
    _dump_to_markdown(enriched_results, "after_extraction")

    # Merge enriched venue results with non-venue task results
    merged_results = dict(task_results)
    for task_name, venues in enriched_results.items():
        merged_results[task_name] = venues

    total_venues = sum(len(v) for v in enriched_results.values())
    events, event_cursor, event_base_cursor = append_event_to_buffer(
        events=events,
        event_cursor=event_cursor,
        event_base_cursor=event_base_cursor,
        payload=ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message=f"Extracted {total_venues} venues",
                icon="✅",
                step="extractor",
            ),
        ).to_payload(),
    )

    return {
        **state,
        "events": events,
        "event_cursor": event_cursor,
        "event_base_cursor": event_base_cursor,
        "task_results": merged_results,
    }
