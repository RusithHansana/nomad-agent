from __future__ import annotations

from datetime import UTC, datetime

from src.agent.state import AgentState
from src.models.response import CostSummary, DayPlan, ItineraryResponse, Venue

HOURS_UNVERIFIED_NOTE = "⚠️ Hours unverified — recommend calling ahead"


def _as_float(value: object, default: float = 0.0) -> float:
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _as_int(value: object) -> int | None:
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _extract_opening_hours(raw: dict[str, object]) -> list[str] | None:
    opening_hours = raw.get("opening_hours") or raw.get("hours")
    if isinstance(opening_hours, list):
        normalized = [str(item) for item in opening_hours if str(item).strip()]
        return normalized or None
    if isinstance(opening_hours, str) and opening_hours.strip():
        return [opening_hours.strip()]
    return None


def _map_result_to_venue(raw: dict[str, object]) -> Venue:
    name = str(raw.get("name") or raw.get("title") or "Unknown Venue").strip() or "Unknown Venue"
    address = (
        str(
            raw.get("address")
            or raw.get("location")
            or raw.get("raw_content")
            or raw.get("content")
            or "Address unavailable"
        ).strip()
        or "Address unavailable"
    )
    source_url = raw.get("source_url") or raw.get("url")
    source_url_str = str(source_url).strip() if source_url else None

    opening_hours = _extract_opening_hours(raw)
    rating = _as_float(raw.get("rating"), default=0.0)
    rating_value = rating if rating > 0 else None
    price_level = _as_int(raw.get("price_level") or raw.get("price"))

    has_structured_details = bool(
        address != "Address unavailable" or opening_hours or rating_value is not None
    )

    hours_verified = opening_hours is not None
    is_verified = bool(source_url_str and has_structured_details and hours_verified)
    verification_note = None if is_verified else "Limited source confidence"
    if not hours_verified:
        verification_note = HOURS_UNVERIFIED_NOTE

    return Venue(
        name=name,
        address=address,
        latitude=_as_float(raw.get("latitude") or raw.get("lat"), default=0.0),
        longitude=_as_float(raw.get("longitude") or raw.get("lng") or raw.get("lon"), default=0.0),
        opening_hours=opening_hours,
        rating=rating_value,
        price_level=price_level,
        source_url=source_url_str,
        is_verified=is_verified,
        verification_note=verification_note,
    )


def _distribute_venues_by_day(venues: list[Venue], duration_days: int) -> list[DayPlan]:
    days = [DayPlan(day_number=index + 1, venues=[]) for index in range(duration_days)]
    for index, venue in enumerate(venues):
        day_index = index % duration_days
        days[day_index].venues.append(venue)
    return days


async def compiler_node(state: AgentState) -> AgentState:
    """Compile researched results into response-ready structures."""
    if state.get("error_event") is not None:
        return {**state, "itinerary_response": None}

    destination = (
        str(state.get("destination", "Unknown Destination")).strip() or "Unknown Destination"
    )
    duration_days = max(1, int(state.get("duration_days", 1)))

    venues: list[Venue] = []
    for task_entries in state.get("task_results", {}).values():
        for entry in task_entries:
            if isinstance(entry, dict):
                venues.append(_map_result_to_venue(entry))

    days = _distribute_venues_by_day(venues, duration_days)
    itinerary = ItineraryResponse(
        destination=destination,
        duration_days=duration_days,
        days=days,
        cost_summary=CostSummary(total=0.0),
        generated_at=datetime.now(UTC).isoformat(),
    )

    return {
        **state,
        "itinerary_response": itinerary.model_dump(exclude_none=True),
    }
