from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from typing import Any

from src.agent.state import AgentState, append_event_to_buffer, get_event_buffer
from src.config import get_settings
from src.models.events import ThoughtLogData, ThoughtLogEvent

logger = logging.getLogger(__name__)

VENUE_TASK_NAMES = {"local research", "event checking"}
MAX_RAW_CONTENT_CHARS = 1500
MAX_CONTENT_CHARS = 800
MAX_VENUES_PER_GENERATION = 15

EXTRACTION_PROMPT = """You are a travel data extraction assistant. Given web search results about places in {destination}, extract structured venue information.

For each REAL venue, restaurant, attraction, or event mentioned, extract:
- name: the actual venue name (NOT the page title or website name)
- address: street address or neighborhood location (NOT URLs or page content)
- latitude: decimal latitude if determinable, otherwise null
- longitude: decimal longitude if determinable, otherwise null
- opening_hours: list of strings like ["Mon-Fri 9:00-17:00"] if mentioned, otherwise null
- rating: numeric rating out of 5.0 if mentioned, otherwise null
- price_level: integer 1-4 (1=budget, 2=moderate, 3=upscale, 4=luxury) if determinable, otherwise null

Rules:
- Extract ONLY real, named venues — skip aggregator pages, listicle headers, generic articles
- A single search result page may describe multiple venues — extract them all
- For latitude/longitude, use your knowledge of well-known venues if coordinates are not in the text
- Maximum {max_venues} venues total

Search results:
{results_block}

Respond with ONLY a JSON array of venue objects. No markdown fencing, no explanation."""


def _format_results_block(
    task_results: dict[str, list[dict[str, object]]],
) -> tuple[str, dict[str, list[dict[str, object]]]]:
    """Build the formatted results text and track which source URLs map to which tasks."""
    sections: list[str] = []
    source_map: dict[str, list[dict[str, object]]] = {}

    for task_name, entries in task_results.items():
        if task_name.strip().lower() not in VENUE_TASK_NAMES:
            continue
        if not isinstance(entries, list):
            continue

        task_lines: list[str] = [f"--- Task: {task_name} ---"]
        for entry in entries:
            if not isinstance(entry, dict):
                continue

            title = str(entry.get("title") or "").strip()
            url = str(entry.get("url") or "").strip()
            content = str(entry.get("content") or "").strip()[:MAX_CONTENT_CHARS]
            raw_content = str(entry.get("raw_content") or "").strip()[:MAX_RAW_CONTENT_CHARS]

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

        if len(task_lines) > 1:
            sections.append("\n\n".join(task_lines))

        source_map[task_name] = entries

    return "\n\n".join(sections), source_map


def _build_extraction_prompt(destination: str, results_block: str) -> str:
    return EXTRACTION_PROMPT.format(
        destination=destination,
        max_venues=MAX_VENUES_PER_GENERATION,
        results_block=results_block,
    )


def _parse_extraction_response(response_text: str) -> list[dict[str, Any]]:
    """Parse LLM response into a list of venue dicts."""
    cleaned = response_text.strip()

    # Strip markdown code fences if present
    if cleaned.startswith("```"):
        first_newline = cleaned.find("\n")
        if first_newline != -1:
            cleaned = cleaned[first_newline + 1 :]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        cleaned = cleaned.strip()

    parsed = json.loads(cleaned)
    if not isinstance(parsed, list):
        return []

    venues: list[dict[str, Any]] = []
    for item in parsed:
        if isinstance(item, dict) and item.get("name"):
            venues.append(item)

    return venues[:MAX_VENUES_PER_GENERATION]


def _enrich_venues_with_source(
    extracted_venues: list[dict[str, Any]],
    source_map: dict[str, list[dict[str, object]]],
) -> dict[str, list[dict[str, object]]]:
    """Distribute extracted venues back into task-keyed results with source URLs preserved."""
    all_source_urls: list[str] = []
    all_degraded_flags: list[bool] = []

    for entries in source_map.values():
        for entry in entries:
            if isinstance(entry, dict):
                url = str(entry.get("url") or "").strip()
                all_source_urls.append(url)
                all_degraded_flags.append(bool(entry.get("_degraded_unverified")))

    enriched_results: dict[str, list[dict[str, object]]] = {}
    task_names = [name for name in source_map]
    venue_index = 0

    # Distribute venues evenly across venue tasks
    venues_per_task = max(1, len(extracted_venues) // max(1, len(task_names)))

    for task_idx, task_name in enumerate(task_names):
        task_venues: list[dict[str, object]] = []
        is_last_task = task_idx == len(task_names) - 1
        end_index = len(extracted_venues) if is_last_task else venue_index + venues_per_task

        while venue_index < end_index and venue_index < len(extracted_venues):
            venue = dict(extracted_venues[venue_index])

            # Preserve source_url from original results where possible
            if not venue.get("source_url") and venue_index < len(all_source_urls):
                venue["source_url"] = all_source_urls[venue_index]
            elif not venue.get("source_url"):
                venue["source_url"] = all_source_urls[0] if all_source_urls else None

            # Preserve degraded flag
            if venue_index < len(all_degraded_flags) and all_degraded_flags[venue_index]:
                venue["_degraded_unverified"] = True

            task_venues.append(venue)
            venue_index += 1

        enriched_results[task_name] = task_venues

    return enriched_results


async def _call_gemini(prompt: str) -> str | None:
    """Call Gemini 2.0 Flash for venue extraction. Returns response text or None on failure."""
    settings = get_settings()
    if not settings.gemini_api_key:
        logger.warning("Gemini API key not configured — skipping extraction")
        return None

    try:
        from google import genai

        client = genai.Client(api_key=settings.gemini_api_key)
        response = await client.aio.models.generate_content(
            model="gemini-2.0-flash",
            contents=prompt,
            config=genai.types.GenerateContentConfig(
                temperature=0.1,
                max_output_tokens=4096,
                response_mime_type="application/json",
            ),
        )
        return response.text
    except Exception:
        logger.exception("Gemini extraction call failed")
        return None


async def extractor_node(
    state: AgentState,
    *,
    llm_caller: Any | None = None,
) -> AgentState:
    """Extract structured venue data from raw Tavily results using Gemini."""
    if state.get("error_event") is not None:
        return state

    events, event_cursor, event_base_cursor = get_event_buffer(state)

    raw_task_results = state.get("task_results", {})
    task_results = dict(raw_task_results) if isinstance(raw_task_results, dict) else {}
    destination = str(state.get("destination", "")).strip() or "Unknown Destination"

    # Check if there are any venue tasks to process
    has_venue_tasks = any(
        name.strip().lower() in VENUE_TASK_NAMES
        for name in task_results
        if isinstance(name, str)
    )

    if not has_venue_tasks:
        return {**state, "events": events, "event_cursor": event_cursor, "event_base_cursor": event_base_cursor}

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

    results_block, source_map = _format_results_block(task_results)
    if not results_block.strip():
        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
        }

    prompt = _build_extraction_prompt(destination, results_block)

    # Use injected caller for testing, or real Gemini
    if llm_caller is not None:
        response_text = await llm_caller(prompt)
    else:
        response_text = await _call_gemini(prompt)

    if response_text is None:
        # Graceful fallback — keep original Tavily results
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

    try:
        extracted_venues = _parse_extraction_response(response_text)
    except (json.JSONDecodeError, ValueError):
        logger.warning("Failed to parse Gemini extraction response")
        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
        }

    if not extracted_venues:
        return {
            **state,
            "events": events,
            "event_cursor": event_cursor,
            "event_base_cursor": event_base_cursor,
        }

    enriched_results = _enrich_venues_with_source(extracted_venues, source_map)

    # Merge enriched venue results with non-venue task results
    merged_results = dict(task_results)
    for task_name, venues in enriched_results.items():
        merged_results[task_name] = venues

    events, event_cursor, event_base_cursor = append_event_to_buffer(
        events=events,
        event_cursor=event_cursor,
        event_base_cursor=event_base_cursor,
        payload=ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message=f"Extracted {sum(len(v) for v in enriched_results.values())} venues",
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
