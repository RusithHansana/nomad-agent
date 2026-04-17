from __future__ import annotations

import json
from typing import AsyncIterator

from fastapi import APIRouter, Depends
from sse_starlette import EventSourceResponse

from src.api.dependencies import validate_api_key
from src.models.request import PromptRequest
from src.services.generation_stream import stream_itinerary_events

_ALLOWED_SSE_EVENT_NAMES = {
    "thought_log",
    "venue_verified",
    "self_correction",
    "itinerary_complete",
    "error",
}


def _sanitize_sse_event_name(event_type: object) -> str:
    raw = str(event_type or "").replace("\r", " ").replace("\n", " ").strip()
    if raw in _ALLOWED_SSE_EVENT_NAMES:
        return raw
    return "message"


router = APIRouter(prefix="/api/v1")


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/generate", dependencies=[Depends(validate_api_key)])
async def generate_itinerary(request: PromptRequest) -> EventSourceResponse:
    async def event_stream() -> AsyncIterator[dict[str, str]]:
        async for payload in stream_itinerary_events(request.prompt):
            event_type = _sanitize_sse_event_name(payload.get("event_type"))
            yield {
                "event": event_type,
                "data": json.dumps(payload, ensure_ascii=False, default=str),
            }

    return EventSourceResponse(
        event_stream(),
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
