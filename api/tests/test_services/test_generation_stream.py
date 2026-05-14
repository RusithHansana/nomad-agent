import pytest

from src.services.generation_stream import stream_itinerary_events


class FakeStreamGraph:
    def __init__(self, final_state: dict[str, object]) -> None:
        self._final_state = final_state

    async def astream(self, _: dict[str, object], *, stream_mode: str) -> object:
        yield self._final_state


@pytest.mark.asyncio
async def test_stream_emits_itinerary_complete_when_tavily_unavailable(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    itinerary_payload = {
        "destination": "Kandy",
        "duration_days": 1,
        "days": [
            {
                "day_number": 1,
                "venues": [
                    {
                        "name": "Temple of the Tooth",
                        "address": "Sri Dalada Veediya, Kandy",
                        "latitude": 7.2935,
                        "longitude": 80.6411,
                        "is_verified": False,
                        "verification_note": "AI-suggested — live verification was unavailable",
                    }
                ],
            }
        ],
        "cost_summary": {"total": 0.0},
        "generated_at": "2026-05-02T12:00:00Z",
        "degraded": True,
        "degradation_reason": "tavily_unavailable",
    }
    final_state = {
        "events": [],
        "event_cursor": 0,
        "event_base_cursor": 1,
        "error_event": None,
        "itinerary_response": itinerary_payload,
        "tavily_unavailable": True,
    }

    monkeypatch.setattr(
        "src.services.generation_stream.build_graph",
        lambda: FakeStreamGraph(final_state),
    )

    events = [event async for event in stream_itinerary_events("trip to Kandy")]

    assert any(event.get("event_type") == "itinerary_complete" for event in events)
    assert all(event.get("event_type") != "error" for event in events)
