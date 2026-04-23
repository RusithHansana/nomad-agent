from __future__ import annotations

from typing import TypedDict

MAX_TASKS = 3
MAX_RESULTS_PER_TASK = 3
MAX_TAVILY_CALLS = 9
GENERATION_TIMEOUT_SECONDS = 120
MAX_SEARCH_ITERATIONS_PER_TASK = 5

# SSE streaming state is built around a bounded event buffer.
# `event_cursor` is a monotonic counter that increments per appended event.
# `event_base_cursor` is the cursor value of the first element in the `events` list.
EVENT_HISTORY_LIMIT = 200


class ResearchTask(TypedDict):
    """Represents a single research task and its generated query."""

    name: str
    query: str


class AgentState(TypedDict):
    """Mutable state passed through the LangGraph workflow."""

    prompt: str
    destination: str
    duration_days: int
    interest_categories: list[str]
    tasks: list[ResearchTask]
    tavily_calls_made: int
    event_cursor: int
    event_base_cursor: int
    events: list[dict[str, object]]
    task_results: dict[str, list[dict[str, object]]]
    error_event: dict[str, object] | None
    itinerary_response: dict[str, object] | None


def _coerce_int(value: object, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def get_event_buffer(state: AgentState) -> tuple[list[dict[str, object]], int, int]:
    """Return a normalized (events, cursor, base_cursor) triple for the state."""
    raw_events = state.get("events")
    events = list(raw_events) if isinstance(raw_events, list) else []

    cursor = _coerce_int(state.get("event_cursor"), 0)
    base_cursor_raw = state.get("event_base_cursor")
    if isinstance(base_cursor_raw, int):
        base_cursor = base_cursor_raw
    else:
        # Best-effort reconstruction if older state didn't carry base_cursor.
        base_cursor = max(1, cursor - len(events) + 1) if events else max(1, cursor + 1)

    if not events:
        base_cursor = max(1, cursor + 1)
    else:
        base_cursor = max(1, base_cursor)

    return events, cursor, base_cursor


def append_event_to_buffer(
    *,
    events: list[dict[str, object]],
    event_cursor: int,
    event_base_cursor: int,
    payload: dict[str, object],
    limit: int = EVENT_HISTORY_LIMIT,
) -> tuple[list[dict[str, object]], int, int]:
    """Append an event payload while enforcing bounded history semantics."""
    next_cursor = event_cursor + 1
    next_events = list(events)

    next_base = event_base_cursor
    if not next_events:
        next_base = next_cursor

    next_events.append(payload)

    if limit > 0 and len(next_events) > limit:
        overflow = len(next_events) - limit
        del next_events[:overflow]
        next_base = max(1, next_base + overflow)

    return next_events, next_cursor, next_base
