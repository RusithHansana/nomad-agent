from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from src.models.response import ItineraryResponse, Venue


class SSEEvent(BaseModel):
    event_type: str
    timestamp: str
    data: dict[str, object]

    @classmethod
    def from_payload(cls, payload: dict[str, object]) -> "SSEEvent":
        return cls.model_validate(payload)

    def to_payload(self) -> dict[str, object]:
        return self.model_dump(exclude_none=True)

    @classmethod
    def parse_payload(cls, payload: dict[str, object]) -> "SSEEvent":
        event_type = payload.get("event_type")
        model = _EVENT_TYPE_TO_MODEL.get(event_type, cls)
        return model.model_validate(payload)


class ThoughtLogData(BaseModel):
    message: str
    icon: str | None = None
    step: str | None = None


class ThoughtLogEvent(SSEEvent):
    event_type: Literal["thought_log"] = "thought_log"
    data: ThoughtLogData


class VenueVerifiedData(BaseModel):
    venue: Venue


class VenueVerifiedEvent(SSEEvent):
    event_type: Literal["venue_verified"] = "venue_verified"
    data: VenueVerifiedData


class SelfCorrectionData(BaseModel):
    original_query: str
    broadened_query: str
    reason: str | None = None


class SelfCorrectionEvent(SSEEvent):
    event_type: Literal["self_correction"] = "self_correction"
    data: SelfCorrectionData


class ItineraryCompleteData(BaseModel):
    itinerary: ItineraryResponse


class ItineraryCompleteEvent(SSEEvent):
    event_type: Literal["itinerary_complete"] = "itinerary_complete"
    data: ItineraryCompleteData


class ErrorData(BaseModel):
    code: str
    message: str
    details: dict[str, object] = Field(default_factory=dict)


class ErrorEvent(SSEEvent):
    event_type: Literal["error"] = "error"
    data: ErrorData


_EVENT_TYPE_TO_MODEL: dict[object, type[SSEEvent]] = {
    "thought_log": ThoughtLogEvent,
    "venue_verified": VenueVerifiedEvent,
    "self_correction": SelfCorrectionEvent,
    "itinerary_complete": ItineraryCompleteEvent,
    "error": ErrorEvent,
}
