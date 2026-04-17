from __future__ import annotations

import json
from typing import AsyncIterator

from fastapi import APIRouter, Depends
from sse_starlette import EventSourceResponse

from src.api.dependencies import validate_api_key
from src.models.request import PromptRequest
from src.services.generation_stream import stream_itinerary_events

router = APIRouter(prefix="/api/v1")


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/generate", dependencies=[Depends(validate_api_key)])
async def generate_itinerary(request: PromptRequest) -> EventSourceResponse:
    async def event_stream() -> AsyncIterator[dict[str, str]]:
        async for payload in stream_itinerary_events(request.prompt):
            event_type = str(payload.get("event_type", "message"))
            yield {
                "event": event_type,
                "data": json.dumps(payload, ensure_ascii=False),
            }

    return EventSourceResponse(
        event_stream(),
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
