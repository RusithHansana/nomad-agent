from datetime import datetime

import pytest

from src.agent.nodes.compiler import HOURS_UNVERIFIED_NOTE, compiler_node


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
                    "url": "https://example.com/timeout",
                },
                {
                    "title": "MAAT Museum",
                    "content": "Museu de Arte, Arquitetura e Tecnologia",
                    "url": "https://example.com/maat",
                },
            ]
        },
        "error_event": None,
    }

    result = await compiler_node(state)  # type: ignore[arg-type]

    itinerary = result["itinerary_response"]
    assert isinstance(itinerary, dict)
    assert itinerary["destination"] == "Lisbon"
    assert itinerary["duration_days"] == 2
    assert itinerary["cost_summary"]["total"] == 0.0
    assert len(itinerary["days"]) == 2
    assert len(itinerary["days"][0]["venues"]) + len(itinerary["days"][1]["venues"]) == 2
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

    venue = result["itinerary_response"]["days"][0]["venues"][0]
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

    venue = result["itinerary_response"]["days"][0]["venues"][0]
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

    venue = result["itinerary_response"]["days"][0]["venues"][0]
    assert venue["is_verified"] is False
    assert venue["verification_note"] == "Limited source confidence"
