from __future__ import annotations

import asyncio

from pydantic import ValidationError

from src.agent.graph import build_graph
from src.agent.state import GENERATION_TIMEOUT_SECONDS
from src.models.response import ItineraryResponse


class InvalidPromptError(RuntimeError):
    """Raised when a prompt violates planner safety rules."""


class TavilyUnavailableServiceError(RuntimeError):
    """Raised when Tavily cannot be used to complete research."""


class GenerationTimeoutError(RuntimeError):
    """Raised when itinerary generation exceeds hard timeout."""


class GenerationPipelineError(RuntimeError):
    """Raised when the generation pipeline returns invalid output."""


async def generate_itinerary_response(prompt: str) -> dict[str, object]:
    """Run the agent pipeline and return a validated itinerary payload."""
    graph = build_graph()
    initial_state: dict[str, object] = {
        "prompt": prompt,
        "destination": "",
        "duration_days": 1,
        "interest_categories": [],
        "tasks": [],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
        "itinerary_response": None,
    }

    try:
        final_state = await asyncio.wait_for(
            graph.ainvoke(initial_state),
            timeout=GENERATION_TIMEOUT_SECONDS,
        )
    except TimeoutError as exc:
        raise GenerationTimeoutError("Generation timed out") from exc

    error_event = final_state.get("error_event") if isinstance(final_state, dict) else None
    if isinstance(error_event, dict):
        error_data = error_event.get("data")
        if isinstance(error_data, dict):
            code = str(error_data.get("code", "")).strip()
            message = str(error_data.get("message", "Request could not be processed")).strip()
            if code == "INVALID_PROMPT":
                raise InvalidPromptError(message)
            if code == "TAVILY_UNAVAILABLE":
                raise TavilyUnavailableServiceError(message)
            raise GenerationPipelineError(message)

    itinerary_payload = (
        final_state.get("itinerary_response") if isinstance(final_state, dict) else None
    )
    if not isinstance(itinerary_payload, dict):
        raise GenerationPipelineError("Pipeline did not produce an itinerary")

    try:
        response_model = ItineraryResponse.model_validate(itinerary_payload)
    except ValidationError as exc:
        raise GenerationPipelineError("Pipeline produced invalid itinerary payload") from exc

    return response_model.model_dump(exclude_none=True)
