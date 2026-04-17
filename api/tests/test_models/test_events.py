from src.models.events import (
    ErrorData,
    ErrorEvent,
    ItineraryCompleteData,
    ItineraryCompleteEvent,
    SelfCorrectionData,
    SelfCorrectionEvent,
    ThoughtLogData,
    ThoughtLogEvent,
    VenueVerifiedData,
    VenueVerifiedEvent,
)
from src.models.response import CostSummary, DayPlan, ItineraryResponse, Venue


def _sample_itinerary() -> ItineraryResponse:
    return ItineraryResponse(
        destination="Lisbon",
        duration_days=1,
        days=[
            DayPlan(
                day_number=1,
                venues=[
                    Venue(
                        name="Ocean View",
                        address="123 Coast Rd",
                        latitude=38.7223,
                        longitude=-9.1393,
                        is_verified=True,
                    )
                ],
            )
        ],
        cost_summary=CostSummary(total=0.0),
        generated_at="2026-04-17T00:00:00+00:00",
    )


def test_required_event_payload_shapes_use_typed_schema() -> None:
    venue = _sample_itinerary().days[0].venues[0]
    itinerary = _sample_itinerary()

    events = [
        ThoughtLogEvent(
            timestamp="2026-04-17T00:00:00+00:00",
            data=ThoughtLogData(message="Starting", step="start"),
        ),
        VenueVerifiedEvent(
            timestamp="2026-04-17T00:00:01+00:00",
            data=VenueVerifiedData(venue=venue),
        ),
        SelfCorrectionEvent(
            timestamp="2026-04-17T00:00:02+00:00",
            data=SelfCorrectionData(
                original_query="best museums in colombo with opening hours",
                broadened_query="best museums in and around colombo",
                reason="insufficient_results",
            ),
        ),
        ItineraryCompleteEvent(
            timestamp="2026-04-17T00:00:03+00:00",
            data=ItineraryCompleteData(itinerary=itinerary),
        ),
        ErrorEvent(
            timestamp="2026-04-17T00:00:04+00:00",
            data=ErrorData(code="GENERATION_FAILED", message="Try again", details={}),
        ),
    ]

    payloads = [event.to_payload() for event in events]

    assert [payload["event_type"] for payload in payloads] == [
        "thought_log",
        "venue_verified",
        "self_correction",
        "itinerary_complete",
        "error",
    ]

    for payload in payloads:
        assert set(payload.keys()) == {"event_type", "timestamp", "data"}
        assert isinstance(payload["data"], dict)

    assert payloads[0]["data"] == {"message": "Starting", "step": "start"}
    assert payloads[1]["data"]["venue"]["is_verified"] is True
    assert payloads[2]["data"]["reason"] == "insufficient_results"
    assert payloads[3]["data"]["itinerary"]["destination"] == "Lisbon"
    assert payloads[4]["data"]["code"] == "GENERATION_FAILED"
