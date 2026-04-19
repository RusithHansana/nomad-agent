from __future__ import annotations

import math
from datetime import UTC, datetime

from src.agent.state import AgentState
from src.models.events import ThoughtLogData, ThoughtLogEvent
from src.models.response import CostSummary, DayPlan, ItineraryResponse, Venue

HOURS_UNVERIFIED_NOTE = "⚠️ Hours unverified — recommend calling ahead"
VENUE_TASK_NAMES = {"local research", "event checking"}
TIME_SLOTS = ("morning", "midday", "afternoon", "evening")
PRICE_LEVEL_COST_MAP = {
    1: 15.0,
    2: 30.0,
    3: 55.0,
    4: 90.0,
}
TRANSPORT_COST_PER_KM = 0.75
FOOD_KEYWORDS = {
    "restaurant",
    "cafe",
    "coffee",
    "bar",
    "bistro",
    "brunch",
    "ramen",
    "pizza",
    "diner",
    "eatery",
    "bakery",
    "pub",
    "food",
}


def _as_float(value: object, default: float = 0.0) -> float:
    if not isinstance(value, (int, float, str)):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _as_int(value: object) -> int | None:
    if not isinstance(value, (int, float, str)):
        return None
    try:
        return int(value)
    except (TypeError, ValueError):
        return None


def _normalize_price_level(value: object) -> int | None:
    direct_int = _as_int(value)
    if direct_int is not None:
        return direct_int if 1 <= direct_int <= 4 else None

    if isinstance(value, str):
        cleaned = value.strip().lower()
        if not cleaned:
            return None
        if "$" in cleaned:
            dollar_count = cleaned.count("$")
            if 1 <= dollar_count <= 4:
                return dollar_count
            if dollar_count > 4:
                return 4

        keyword_map = {
            "cheap": 1,
            "budget": 1,
            "moderate": 2,
            "mid-range": 2,
            "upscale": 3,
            "expensive": 4,
            "luxury": 4,
        }
        return keyword_map.get(cleaned)

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
    price_level = _normalize_price_level(raw.get("price_level") or raw.get("price"))

    has_structured_details = bool(
        address != "Address unavailable" or opening_hours or rating_value is not None
    )

    hours_verified = opening_hours is not None
    force_unverified = bool(raw.get("_degraded_unverified"))
    is_verified = bool(
        source_url_str and has_structured_details and hours_verified and not force_unverified
    )

    if not hours_verified:
        verification_note = HOURS_UNVERIFIED_NOTE
    elif force_unverified:
        verification_note = "Limited source confidence"
    else:
        verification_note = None if is_verified else "Limited source confidence"

    estimated_cost = PRICE_LEVEL_COST_MAP.get(price_level) if price_level is not None else None

    return Venue(
        name=name,
        address=address,
        latitude=_as_float(raw.get("latitude") or raw.get("lat"), default=0.0),
        longitude=_as_float(raw.get("longitude") or raw.get("lng") or raw.get("lon"), default=0.0),
        opening_hours=opening_hours,
        rating=rating_value,
        price_level=price_level,
        estimated_cost=estimated_cost,
        source_url=source_url_str,
        is_verified=is_verified,
        verification_note=verification_note,
    )


def _distribute_venues_by_day(venues: list[Venue], duration_days: int) -> list[DayPlan]:
    days = [DayPlan(day_number=index + 1, venues=[]) for index in range(duration_days)]
    if not venues:
        return days

    venues_per_day = max(1, math.ceil(len(venues) / duration_days))
    for day_index in range(duration_days):
        start = day_index * venues_per_day
        end = start + venues_per_day
        days[day_index].venues = list(venues[start:end])

    return days


def _is_venue_task(task_name: object) -> bool:
    if not isinstance(task_name, str):
        return False
    return task_name.strip().lower() in VENUE_TASK_NAMES


def _has_valid_coordinates(venue: Venue) -> bool:
    if venue.latitude == 0.0 and venue.longitude == 0.0:
        return False
    return -90.0 <= venue.latitude <= 90.0 and -180.0 <= venue.longitude <= 180.0


def _distance_km(first: Venue, second: Venue) -> float:
    lat1 = math.radians(first.latitude)
    lon1 = math.radians(first.longitude)
    lat2 = math.radians(second.latitude)
    lon2 = math.radians(second.longitude)

    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) ** 2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    earth_radius_km = 6371.0
    return earth_radius_km * c


def _nearest_neighbor_order(venues: list[Venue]) -> list[Venue]:
    if not venues:
        return []

    remaining = list(enumerate(venues))
    ordered: list[Venue] = []
    current_index, current_venue = remaining.pop(0)
    ordered.append(current_venue)

    while remaining:
        next_position = min(
            range(len(remaining)),
            key=lambda pos: (
                _distance_km(current_venue, remaining[pos][1]),
                remaining[pos][0],
            ),
        )
        current_index, current_venue = remaining.pop(next_position)
        ordered.append(current_venue)

    return ordered


def _optimize_day_venues(venues: list[Venue]) -> list[Venue]:
    if len(venues) < 3:
        return venues

    valid_indices = [index for index, venue in enumerate(venues) if _has_valid_coordinates(venue)]
    if len(valid_indices) < 3:
        return venues

    valid_venues = [venues[index] for index in valid_indices]
    optimized_valid = _nearest_neighbor_order(valid_venues)

    optimized = list(venues)
    for index, venue in zip(valid_indices, optimized_valid, strict=False):
        optimized[index] = venue
    return optimized


def _with_time_slots(venues: list[Venue]) -> list[Venue]:
    planned: list[Venue] = []
    for index, venue in enumerate(venues):
        planned.append(venue.model_copy(update={"time_slot": TIME_SLOTS[index % len(TIME_SLOTS)]}))
    return planned


def _is_food_venue(venue: Venue) -> bool:
    searchable = f"{venue.name} {venue.address}".lower()
    return any(keyword in searchable for keyword in FOOD_KEYWORDS)


def _sum_day_cost(venues: list[Venue]) -> float:
    return round(sum((venue.estimated_cost or 0.0) for venue in venues), 2)


def _compute_transport_cost(days: list[DayPlan]) -> float:
    total_distance_km = 0.0
    for day in days:
        for current, nxt in zip(day.venues, day.venues[1:], strict=False):
            if _has_valid_coordinates(current) and _has_valid_coordinates(nxt):
                total_distance_km += _distance_km(current, nxt)
    return round(total_distance_km * TRANSPORT_COST_PER_KM, 2)


def _build_cost_summary(days: list[DayPlan]) -> CostSummary:
    food_total = 0.0
    entertainment_total = 0.0
    for day in days:
        for venue in day.venues:
            venue_cost = venue.estimated_cost or 0.0
            if _is_food_venue(venue):
                food_total += venue_cost
            else:
                entertainment_total += venue_cost

    food_total = round(food_total, 2)
    entertainment_total = round(entertainment_total, 2)
    transport_total = _compute_transport_cost(days)
    total = round(food_total + entertainment_total + transport_total, 2)

    return CostSummary(
        food=food_total,
        entertainment=entertainment_total,
        transport=transport_total,
        total=total,
    )


async def compiler_node(state: AgentState) -> AgentState:
    """Compile researched results into response-ready structures."""
    if state.get("error_event") is not None:
        return {**state, "itinerary_response": None}

    destination = (
        str(state.get("destination", "Unknown Destination")).strip() or "Unknown Destination"
    )
    duration_days = max(1, int(state.get("duration_days", 1)))
    raw_events = state.get("events")
    events = list(raw_events) if isinstance(raw_events, list) else []
    events.append(
        ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message="Compiling itinerary",
                step="compiler",
            ),
        ).to_payload()
    )

    venues: list[Venue] = []
    for task_name, task_entries in state.get("task_results", {}).items():
        if not _is_venue_task(task_name):
            continue
        for entry in task_entries:
            if isinstance(entry, dict):
                venues.append(_map_result_to_venue(entry))

    days = _distribute_venues_by_day(venues, duration_days)
    optimized_days: list[DayPlan] = []
    for day in days:
        optimized_venues = _optimize_day_venues(day.venues)
        slotted_venues = _with_time_slots(optimized_venues)
        optimized_days.append(
            day.model_copy(
                update={
                    "venues": slotted_venues,
                    "estimated_day_cost": _sum_day_cost(slotted_venues),
                }
            )
        )

    cost_summary = _build_cost_summary(optimized_days)

    itinerary = ItineraryResponse(
        destination=destination,
        duration_days=duration_days,
        days=optimized_days,
        cost_summary=cost_summary,
        generated_at=datetime.now(UTC).isoformat(),
    )
    events.append(
        ThoughtLogEvent(
            timestamp=datetime.now(UTC).isoformat(),
            data=ThoughtLogData(
                message="Itinerary complete",
                icon="🎉",
                step="compiler",
            ),
        ).to_payload()
    )

    return {
        **state,
        "events": events,
        "itinerary_response": itinerary.model_dump(exclude_none=True),
    }
