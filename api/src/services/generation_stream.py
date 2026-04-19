from __future__ import annotations

import asyncio
import contextlib
import time
from datetime import UTC, datetime
from typing import AsyncIterator

from src.agent.graph import build_graph
from src.agent.state import GENERATION_TIMEOUT_SECONDS
from src.models.events import (
    ErrorData,
    ErrorEvent,
    ItineraryCompleteData,
    ItineraryCompleteEvent,
    SSEEvent,
    ThoughtLogData,
    ThoughtLogEvent,
    VenueVerifiedData,
    VenueVerifiedEvent,
)
from src.models.response import ItineraryResponse


def _coerce_int(value: object, default: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _compute_event_delta(
    *,
    events: list[dict[str, object]],
    base_cursor: int,
    last_sent_cursor: int,
) -> tuple[list[dict[str, object]], int]:
    """Return the next event slice and the updated last_sent_cursor.

    Cursors are 1-based for the first event appended into the buffer.
    `base_cursor` is the cursor of events[0].
    """
    if not events:
        return [], last_sent_cursor

    base_cursor = max(1, base_cursor)

    if last_sent_cursor < base_cursor - 1:
        start_index = 0
    else:
        start_index = (last_sent_cursor + 1) - base_cursor

    if start_index < 0:
        start_index = 0
    if start_index >= len(events):
        return [], last_sent_cursor

    new_last_sent_cursor = base_cursor + len(events) - 1
    return events[start_index:], new_last_sent_cursor


def _utc_now_iso() -> str:
    return datetime.now(UTC).isoformat()


def _error_payload(
    code: str,
    message: str,
    details: dict[str, object] | None = None,
) -> dict[str, object]:
    event = ErrorEvent(
        timestamp=_utc_now_iso(),
        data=ErrorData(
            code=code,
            message=message,
            details=details or {},
        ),
    )
    return event.to_payload()


def _extract_state_from_update(update: object) -> dict[str, object] | None:
    if isinstance(update, dict):
        return update
    return None


async def stream_itinerary_events(prompt: str) -> AsyncIterator[dict[str, object]]:
    """Run generation as an SSE-friendly event stream with typed payloads."""
    initial_state: dict[str, object] = {
        "prompt": prompt,
        "destination": "",
        "duration_days": 1,
        "interest_categories": [],
        "tasks": [],
        "tavily_calls_made": 0,
        "event_cursor": 0,
        "event_base_cursor": 1,
        "events": [],
        "task_results": {},
        "error_event": None,
        "itinerary_response": None,
    }

    # Emit immediately so clients can render activity quickly.
    start_event = ThoughtLogEvent(
        timestamp=_utc_now_iso(),
        data=ThoughtLogData(
            message="Starting research...",
            icon="🔍",
            step="start",
        ),
    )
    yield start_event.to_payload()

    last_sent_cursor = 0
    final_state: dict[str, object] | None = None
    started_at = time.monotonic()
    stream = None

    try:
        graph = build_graph()
        stream = graph.astream(initial_state, stream_mode="values")

        while True:
            elapsed = time.monotonic() - started_at
            remaining_timeout = GENERATION_TIMEOUT_SECONDS - elapsed
            if remaining_timeout <= 0:
                raise TimeoutError("Generation timed out")

            try:
                update = await asyncio.wait_for(stream.__anext__(), timeout=remaining_timeout)
            except StopAsyncIteration:
                break

            state = _extract_state_from_update(update)
            if state is None:
                continue

            final_state = state
            event_payloads = state.get("events", [])
            if not isinstance(event_payloads, list):
                continue

            event_base_cursor = _coerce_int(state.get("event_base_cursor"), 1)
            event_cursor = _coerce_int(state.get("event_cursor"), event_base_cursor - 1)
            # If the cursor appears to reset, reset our sender cursor too.
            if event_cursor < last_sent_cursor:
                last_sent_cursor = 0

            delta_payloads, updated_last_sent = _compute_event_delta(
                events=event_payloads,
                base_cursor=event_base_cursor,
                last_sent_cursor=last_sent_cursor,
            )

            for payload in delta_payloads:
                if not isinstance(payload, dict):
                    continue
                try:
                    yield SSEEvent.parse_payload(payload).to_payload()
                except Exception:
                    continue

            last_sent_cursor = max(last_sent_cursor, updated_last_sent)
    except asyncio.CancelledError:
        raise
    except TimeoutError:
        yield _error_payload(
            code="GENERATION_TIMEOUT",
            message="Generation timed out. Please try again.",
        )
        return
    except Exception:
        yield _error_payload(
            code="GENERATION_FAILED",
            message="Unable to complete generation right now. Please try again.",
        )
        return
    finally:
        aclose = getattr(stream, "aclose", None) if stream is not None else None
        if callable(aclose):
            with contextlib.suppress(Exception):
                await aclose()

    if final_state is None:
        yield _error_payload(
            code="GENERATION_FAILED",
            message="Generation did not return any result.",
        )
        return

    error_event = final_state.get("error_event")
    if isinstance(error_event, dict):
        try:
            yield SSEEvent.parse_payload(error_event).to_payload()
        except Exception:
            yield _error_payload(
                code="GENERATION_FAILED",
                message="Generation produced an invalid error payload.",
            )
        return

    itinerary_payload = final_state.get("itinerary_response")
    if not isinstance(itinerary_payload, dict):
        yield _error_payload(
            code="GENERATION_FAILED",
            message="Generation did not produce an itinerary.",
        )
        return

    try:
        itinerary = ItineraryResponse.model_validate(itinerary_payload)
    except Exception:
        yield _error_payload(
            code="GENERATION_FAILED",
            message="Generated itinerary is invalid.",
        )
        return

    for day in itinerary.days:
        for venue in day.venues:
            if not venue.is_verified:
                continue
            venue_event = VenueVerifiedEvent(
                timestamp=_utc_now_iso(),
                data=VenueVerifiedData(venue=venue),
            )
            yield venue_event.to_payload()

    complete_event = ItineraryCompleteEvent(
        timestamp=_utc_now_iso(),
        data=ItineraryCompleteData(itinerary=itinerary),
    )
    yield complete_event.to_payload()
