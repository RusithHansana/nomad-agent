from src.models.events import (
    ErrorData,
    ErrorEvent,
    ItineraryCompleteData,
    ItineraryCompleteEvent,
)
from src.models.response import CostSummary, DayPlan, ItineraryResponse, Venue


def _build_itinerary() -> ItineraryResponse:
    return ItineraryResponse(
        destination="Tokyo",
        duration_days=1,
        days=[
            DayPlan(
                day_number=1,
                date="2026-04-14",
                venues=[
                    Venue(
                        name="Senso-ji",
                        address="2 Chome-3-1 Asakusa, Taito City, Tokyo",
                        latitude=35.7148,
                        longitude=139.7967,
                        opening_hours=None,
                        rating=4.6,
                        price_level=None,
                        estimated_cost=None,
                        source_url=None,
                        is_verified=False,
                        verification_note="Source unavailable",
                    )
                ],
                estimated_day_cost=None,
            )
        ],
        cost_summary=CostSummary(
            food=None,
            entertainment=20.0,
            transport=None,
            total=20.0,
        ),
        generated_at="2026-04-14T10:00:00Z",
    )


def test_itinerary_model_dump_excludes_none_and_keeps_snake_case() -> None:
    itinerary = _build_itinerary()

    payload = itinerary.model_dump(exclude_none=True)

    assert payload["duration_days"] == 1
    assert payload["generated_at"] == "2026-04-14T10:00:00Z"

    first_venue = payload["days"][0]["venues"][0]
    assert "opening_hours" not in first_venue
    assert "price_level" not in first_venue
    assert "estimated_cost" not in first_venue
    assert "source_url" not in first_venue
    assert "verification_note" in first_venue


def test_itinerary_complete_event_omits_nested_none_values() -> None:
    itinerary = _build_itinerary()
    event = ItineraryCompleteEvent(
        timestamp="2026-04-14T10:00:01Z",
        data=ItineraryCompleteData(itinerary=itinerary),
    )

    payload = event.to_payload()

    venue_payload = payload["data"]["itinerary"]["days"][0]["venues"][0]
    assert payload["event_type"] == "itinerary_complete"
    assert "opening_hours" not in venue_payload


def test_error_event_defaults_details_to_empty_object() -> None:
    event = ErrorEvent(
        timestamp="2026-04-14T10:00:02Z",
        data=ErrorData(code="GENERATION_FAILED", message="Something went wrong"),
    )

    payload = event.to_payload()

    assert payload["data"]["details"] == {}
