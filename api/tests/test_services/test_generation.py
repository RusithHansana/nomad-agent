import pytest

from src.services.generation import GenerationPipelineError, generate_itinerary_response


class FakeGraph:
    def __init__(self, final_state: dict[str, object]) -> None:
        self._final_state = final_state

    async def ainvoke(self, _: dict[str, object]) -> dict[str, object]:
        return self._final_state


@pytest.mark.asyncio
async def test_generate_wraps_itinerary_validation_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    invalid_state = {
        "error_event": None,
        "itinerary_response": {
            "destination": "Lisbon",
            "duration_days": 2,
        },
    }

    monkeypatch.setattr(
        "src.services.generation.build_graph",
        lambda: FakeGraph(invalid_state),
    )

    with pytest.raises(GenerationPipelineError, match="invalid itinerary payload"):
        await generate_itinerary_response("trip to lisbon")
