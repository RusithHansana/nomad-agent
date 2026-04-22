import json
from typing import Any

import pytest

from src.agent.nodes.extractor import (
    MAX_VENUES_PER_TASK,
    VENUE_TASK_NAMES,
    _clean_raw_content,
    _format_results_block_for_task,
    _minify_prompt,
    _parse_extraction_response,
    extractor_node,
)
from src.agent.state import AgentState


def _make_state(
    task_results: dict[str, Any],
    *,
    destination: str = "Tokyo",
    error_event: Any = None,
) -> AgentState:
    return {
        "prompt": "3 days in tokyo",
        "destination": destination,
        "duration_days": 3,
        "interest_categories": ["food", "culture"],
        "tasks": [],
        "tavily_calls_made": 3,
        "events": [],
        "event_cursor": 0,
        "event_base_cursor": 1,
        "task_results": task_results,
        "error_event": error_event,
        "itinerary_response": None,
    }


def _tavily_result(
    title: str,
    url: str = "https://example.com/page",
    content: str = "Some content",
    raw_content: str = "Full page text here",
) -> dict[str, object]:
    return {
        "title": title,
        "url": url,
        "content": content,
        "raw_content": raw_content,
    }


GOOD_EXTRACTION_RESPONSE = json.dumps([
    {
        "name": "Tsukiji Outer Market",
        "address": "4 Chome-16-2 Tsukiji, Chuo City",
        "latitude": 35.6654,
        "longitude": 139.7707,
        "opening_hours": ["Mon-Sun 5:00-14:00"],
        "rating": 4.5,
        "price_level": 2,
    },
    {
        "name": "Senso-ji Temple",
        "address": "2 Chome-3-1 Asakusa, Taito City",
        "latitude": 35.7148,
        "longitude": 139.7967,
        "opening_hours": ["Daily 6:00-17:00"],
        "rating": 4.7,
        "price_level": 1,
    },
])


async def _success_caller(prompt: str) -> str:
    return GOOD_EXTRACTION_RESPONSE


async def _failure_caller(prompt: str) -> str | None:
    return None


async def _invalid_json_caller(prompt: str) -> str:
    return "not valid json at all"


async def _empty_array_caller(prompt: str) -> str:
    return "[]"


async def _markdown_fenced_caller(prompt: str) -> str:
    return f"```json\n{GOOD_EXTRACTION_RESPONSE}\n```"


# --- Unit tests for internal helpers ---


class TestParseExtractionResponse:
    def test_parses_valid_json_array(self) -> None:
        result = _parse_extraction_response(GOOD_EXTRACTION_RESPONSE)
        assert len(result) == 2
        assert result[0]["name"] == "Tsukiji Outer Market"
        assert result[1]["name"] == "Senso-ji Temple"

    def test_strips_markdown_fences(self) -> None:
        fenced = f"```json\n{GOOD_EXTRACTION_RESPONSE}\n```"
        result = _parse_extraction_response(fenced)
        assert len(result) == 2

    def test_returns_empty_for_non_array_json(self) -> None:
        result = _parse_extraction_response('{"key": "value"}')
        assert result == []

    def test_returns_empty_for_invalid_json(self) -> None:
        result = _parse_extraction_response("not json")
        assert result == []

    def test_filters_items_without_name(self) -> None:
        response = json.dumps([
            {"name": "Valid Venue", "address": "123 St"},
            {"address": "456 Ave"},
            {"name": "", "address": "789 Rd"},
        ])
        result = _parse_extraction_response(response)
        assert len(result) == 1
        assert result[0]["name"] == "Valid Venue"

    def test_caps_at_max_venues(self) -> None:
        many_venues = [{"name": f"Venue {i}", "address": f"Addr {i}"} for i in range(30)]
        response = json.dumps(many_venues)
        result = _parse_extraction_response(response)
        assert len(result) == MAX_VENUES_PER_TASK


class TestFormatResultsBlockForTask:
    def test_formats_entries(self) -> None:
        entries = [_tavily_result("Page Title 1")]
        block, valid = _format_results_block_for_task("Local Research", entries)
        assert "Page Title 1" in block
        assert len(valid) == 1

    def test_handles_empty_entries(self) -> None:
        block, valid = _format_results_block_for_task("Local Research", [])
        assert block == ""
        assert valid == []

    def test_skips_non_dict_entries(self) -> None:
        entries = [_tavily_result("Valid"), "invalid", None]
        block, _ = _format_results_block_for_task("Local Research", entries)
        assert "Valid" in block

    def test_skips_entries_with_no_content(self) -> None:
        entries = [{"title": "", "url": "", "content": "", "raw_content": ""}]
        block, _ = _format_results_block_for_task("Local Research", entries)
        # Only the task header, no actual entries
        assert "Title:" not in block


class TestCleanRawContent:
    def test_strips_html_tags(self) -> None:
        html = "<p>Great <b>restaurant</b> in <a href='http://x.com'>Tokyo</a></p>"
        cleaned = _clean_raw_content(html)
        assert "<p>" not in cleaned
        assert "<b>" not in cleaned
        assert "restaurant" in cleaned
        assert "Tokyo" in cleaned

    def test_removes_script_and_style_blocks(self) -> None:
        html = "<script>var x=1;</script>Useful text<style>.a{color:red}</style>"
        cleaned = _clean_raw_content(html)
        assert "var x" not in cleaned
        assert "color:red" not in cleaned
        assert "Useful text" in cleaned

    def test_removes_urls(self) -> None:
        text = "Visit https://example.com/image.jpg for details about Tsukiji Market"
        cleaned = _clean_raw_content(text)
        assert "https://" not in cleaned
        assert "Tsukiji Market" in cleaned

    def test_returns_empty_for_empty_input(self) -> None:
        assert _clean_raw_content("") == ""


class TestMinifyPrompt:
    def test_collapses_whitespace(self) -> None:
        prompt = "Extract   venues    from    results"
        result = _minify_prompt(prompt)
        assert "   " not in result
        assert "Extract venues from results" == result

    def test_collapses_excessive_newlines(self) -> None:
        prompt = "Line 1\n\n\n\n\nLine 2"
        result = _minify_prompt(prompt)
        assert result == "Line 1\n\nLine 2"


# --- Integration tests for extractor_node ---


@pytest.mark.asyncio
async def test_extractor_extracts_structured_venues_from_tavily_results() -> None:
    state = _make_state({
        "Local Research": [
            _tavily_result("THE 10 BEST Tokyo Restaurants - Tripadvisor"),
            _tavily_result("Top Attractions in Tokyo 2026"),
        ],
        "Event Checking": [
            _tavily_result("Tokyo Events This Week"),
        ],
    })

    result = await extractor_node(state, llm_caller=_success_caller)

    assert "Local Research" in result["task_results"] or "Event Checking" in result["task_results"]
    all_venues = []
    for task_name, entries in result["task_results"].items():
        if task_name.strip().lower() in VENUE_TASK_NAMES:
            all_venues.extend(entries)

    # Per-task extraction: success_caller returns 2 venues per call,
    # called once for Local Research and once for Event Checking = 4 total
    assert len(all_venues) == 4
    assert all_venues[0]["name"] == "Tsukiji Outer Market"
    assert all_venues[0]["latitude"] == 35.6654
    assert all_venues[0]["opening_hours"] == ["Mon-Sun 5:00-14:00"]


@pytest.mark.asyncio
async def test_extractor_preserves_source_url_from_original_results() -> None:
    state = _make_state({
        "Local Research": [
            _tavily_result("Restaurant Guide", url="https://tripadvisor.com/tokyo"),
        ],
    })

    result = await extractor_node(state, llm_caller=_success_caller)

    # LLM-extracted venues don't have source_url matching original results;
    # the enrichment maps them via fallback URL from the source_map
    venues = result["task_results"]["Local Research"]
    assert venues[0]["source_url"] == "https://tripadvisor.com/tokyo"


@pytest.mark.asyncio
async def test_extractor_preserves_degraded_flag() -> None:
    state = _make_state({
        "Local Research": [
            {
                **_tavily_result("Restaurant Guide"),
                "_degraded_unverified": True,
            },
        ],
    })

    result = await extractor_node(state, llm_caller=_success_caller)

    venues = result["task_results"]["Local Research"]
    assert venues[0].get("_degraded_unverified") is True


@pytest.mark.asyncio
async def test_extractor_falls_back_on_llm_failure() -> None:
    original_results = {
        "Local Research": [
            _tavily_result("Original Title"),
        ],
    }
    state = _make_state(original_results)

    result = await extractor_node(state, llm_caller=_failure_caller)

    # When all LLM calls fail, no extraction happens and
    # the fallback "extraction unavailable" event is emitted
    fallback_events = [
        e for e in result["events"]
        if isinstance(e, dict) and e.get("event_type") == "thought_log"
        and "unavailable" in str(e.get("data", {}).get("message", "")).lower()
    ]
    assert len(fallback_events) == 1


@pytest.mark.asyncio
async def test_extractor_falls_back_on_invalid_json_response() -> None:
    original_results = {
        "Local Research": [
            _tavily_result("Original Title"),
        ],
    }
    state = _make_state(original_results)

    result = await extractor_node(state, llm_caller=_invalid_json_caller)

    # When parse fails for all tasks, fallback event is emitted
    fallback_events = [
        e for e in result["events"]
        if isinstance(e, dict) and e.get("event_type") == "thought_log"
        and "unavailable" in str(e.get("data", {}).get("message", "")).lower()
    ]
    assert len(fallback_events) == 1


@pytest.mark.asyncio
async def test_extractor_falls_back_on_empty_extraction() -> None:
    original_results = {
        "Local Research": [
            _tavily_result("Original Title"),
        ],
    }
    state = _make_state(original_results)

    result = await extractor_node(state, llm_caller=_empty_array_caller)

    # Empty extraction from all tasks triggers fallback event
    fallback_events = [
        e for e in result["events"]
        if isinstance(e, dict) and e.get("event_type") == "thought_log"
        and "unavailable" in str(e.get("data", {}).get("message", "")).lower()
    ]
    assert len(fallback_events) == 1


@pytest.mark.asyncio
async def test_extractor_skips_non_venue_tasks() -> None:
    state = _make_state({
        "Route Optimization": [
            _tavily_result("How to get around Tokyo"),
        ],
    })

    result = await extractor_node(state, llm_caller=_success_caller)

    # Route Optimization should be untouched
    assert result["task_results"]["Route Optimization"][0]["title"] == "How to get around Tokyo"


@pytest.mark.asyncio
async def test_extractor_handles_empty_task_results() -> None:
    state = _make_state({})

    result = await extractor_node(state, llm_caller=_success_caller)

    assert result["task_results"] == {}


@pytest.mark.asyncio
async def test_extractor_emits_thought_log_events() -> None:
    state = _make_state({
        "Local Research": [_tavily_result("Test")],
    })

    result = await extractor_node(state, llm_caller=_success_caller)

    thought_logs = [
        e for e in result["events"]
        if isinstance(e, dict) and e.get("event_type") == "thought_log"
    ]
    assert len(thought_logs) >= 2  # "Extracting..." and "Extracted N venues"


@pytest.mark.asyncio
async def test_extractor_short_circuits_on_error_event() -> None:
    state = _make_state(
        {"Local Research": [_tavily_result("Test")]},
        error_event={"event_type": "error", "data": {"code": "INVALID_PROMPT"}},
    )

    result = await extractor_node(state, llm_caller=_success_caller)

    # Should return state unchanged
    assert result["task_results"]["Local Research"][0]["title"] == "Test"


@pytest.mark.asyncio
async def test_extractor_handles_markdown_fenced_response() -> None:
    state = _make_state({
        "Local Research": [_tavily_result("Test")],
    })

    result = await extractor_node(state, llm_caller=_markdown_fenced_caller)

    all_venues = []
    for task_name, entries in result["task_results"].items():
        if task_name.strip().lower() in VENUE_TASK_NAMES:
            all_venues.extend(entries)
    assert len(all_venues) == 2
    assert all_venues[0]["name"] == "Tsukiji Outer Market"
