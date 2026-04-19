from datetime import datetime
from typing import Any, cast

import pytest

from src.agent.nodes.compiler import HOURS_UNVERIFIED_NOTE, compiler_node
from src.agent.state import AgentState


def _itinerary_from_result(result: AgentState) -> dict[str, Any]:
    itinerary_payload = result.get("itinerary_response")
    assert isinstance(itinerary_payload, dict)
    return cast(dict[str, Any], itinerary_payload)


@pytest.mark.asyncio
async def test_compiler_builds_itinerary_response_shape() -> None:
    state = {
        "prompt": "trip to lisbon",
        "destination": "Lisbon",
        "duration_days": 2,
        "interest_categories": ["food", "culture"],
        "tasks": [],
        "tavily_calls_made": 3,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Time Out Market",
                    "address": "Av. 24 de Julho",
                    "lat": 38.7071,
                    "lng": -9.1466,
                    "rating": 4.5,
                    "price": "$$",
                    "url": "https://example.com/timeout",
                },
                {
                    "title": "MAAT Museum",
                    "content": "Museu de Arte, Arquitetura e Tecnologia",
                    "price_level": 3,
                    "url": "https://example.com/maat",
                },
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    assert itinerary["destination"] == "Lisbon"
    assert itinerary["duration_days"] == 2
    assert itinerary["cost_summary"]["total"] == 85.0
    assert len(itinerary["days"]) == 2
    assert len(itinerary["days"][0]["venues"]) + len(itinerary["days"][1]["venues"]) == 2
    for day in itinerary["days"]:
        venue_cost_sum = sum((venue.get("estimated_cost") or 0.0) for venue in day["venues"])
        assert day["estimated_day_cost"] == venue_cost_sum
    assert itinerary["days"][0]["venues"][0]["time_slot"] == "morning"
    datetime.fromisoformat(itinerary["generated_at"])


@pytest.mark.asyncio
async def test_compiler_marks_unverified_when_source_or_details_missing() -> None:
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Unknown Place",
                }
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venue = itinerary["days"][0]["venues"][0]
    assert venue["is_verified"] is False
    assert venue["verification_note"] == HOURS_UNVERIFIED_NOTE


@pytest.mark.asyncio
async def test_compiler_keeps_venue_verified_when_hours_present() -> None:
    state = {
        "prompt": "trip",
        "destination": "Colombo",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Cafe Ceylon",
                    "address": "Main Street",
                    "opening_hours": ["Mon-Fri 8:00-22:00"],
                    "url": "https://example.com/cafe-ceylon",
                }
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venue = itinerary["days"][0]["venues"][0]
    assert venue["is_verified"] is True
    assert venue.get("verification_note") is None


@pytest.mark.asyncio
async def test_compiler_forces_unverified_for_degraded_results() -> None:
    state = {
        "prompt": "trip",
        "destination": "Colombo",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Cafe Ceylon",
                    "address": "Main Street",
                    "opening_hours": ["Mon-Fri 8:00-22:00"],
                    "url": "https://example.com/cafe-ceylon",
                    "_degraded_unverified": True,
                }
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venue = itinerary["days"][0]["venues"][0]
    assert venue["is_verified"] is False
    assert venue["verification_note"] == "Limited source confidence"


@pytest.mark.asyncio
async def test_compiler_excludes_route_optimization_results_from_venues() -> None:
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Time Out Market",
                    "address": "Av. 24 de Julho",
                    "opening_hours": ["Mon-Sun 10:00-23:00"],
                    "url": "https://example.com/timeout",
                }
            ],
            "Route Optimization": [
                {
                    "title": "How to route your day",
                    "content": "Take tram 28 and switch near Baixa",
                    "url": "https://example.com/routing-hints",
                }
            ],
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venues = itinerary["days"][0]["venues"]
    assert len(venues) == 1
    assert venues[0]["name"] == "Time Out Market"


@pytest.mark.asyncio
async def test_compiler_optimizes_order_by_proximity_for_valid_coordinates() -> None:
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["culture"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Start Point",
                    "address": "A",
                    "opening_hours": ["Mon-Sun 09:00-18:00"],
                    "lat": 38.7071,
                    "lng": -9.1466,
                    "price_level": 1,
                    "url": "https://example.com/start",
                },
                {
                    "title": "Far Venue",
                    "address": "B",
                    "opening_hours": ["Mon-Sun 09:00-18:00"],
                    "lat": 38.7369,
                    "lng": -9.1427,
                    "price_level": 2,
                    "url": "https://example.com/far",
                },
                {
                    "title": "Near Venue",
                    "address": "C",
                    "opening_hours": ["Mon-Sun 09:00-18:00"],
                    "lat": 38.7090,
                    "lng": -9.1455,
                    "price_level": 2,
                    "url": "https://example.com/near",
                },
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venues = itinerary["days"][0]["venues"]
    assert [venue["name"] for venue in venues] == ["Start Point", "Near Venue", "Far Venue"]


@pytest.mark.asyncio
async def test_compiler_handles_non_integer_duration_days_value() -> None:
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": "3.0",
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Time Out Market",
                    "address": "Av. 24 de Julho",
                    "opening_hours": ["Mon-Sun 10:00-23:00"],
                    "url": "https://example.com/timeout",
                }
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    assert itinerary["duration_days"] == 1
    assert len(itinerary["days"]) == 1


@pytest.mark.asyncio
async def test_compiler_ignores_non_list_task_result_entries() -> None:
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": {
                "title": "This should be ignored",
            }
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    assert len(itinerary["days"]) == 1
    assert itinerary["days"][0]["venues"] == []


@pytest.mark.asyncio
async def test_compiler_treats_string_false_degraded_flag_as_false() -> None:
    state = {
        "prompt": "trip",
        "destination": "Colombo",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [],
        "tavily_calls_made": 1,
        "events": [],
        "task_results": {
            "Local Research": [
                {
                    "title": "Cafe Ceylon",
                    "address": "Main Street",
                    "opening_hours": ["Mon-Fri 8:00-22:00"],
                    "url": "https://example.com/cafe-ceylon",
                    "_degraded_unverified": "false",
                }
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = _itinerary_from_result(result)
    venue = itinerary["days"][0]["venues"][0]
    assert venue["is_verified"] is True
    assert venue.get("verification_note") is None
