from __future__ import annotations

from pydantic import BaseModel


class ModelBase(BaseModel):
    def to_payload(self) -> dict[str, object]:
        return self.model_dump(exclude_none=True)


class Venue(ModelBase):
    name: str
    address: str
    latitude: float
    longitude: float
    opening_hours: list[str] | None = None
    rating: float | None = None
    price_level: int | None = None
    estimated_cost: float | None = None
    time_slot: str | None = None
    source_url: str | None = None
    is_verified: bool
    verification_note: str | None = None


class DayPlan(ModelBase):
    day_number: int
    date: str | None = None
    venues: list[Venue]
    estimated_day_cost: float | None = None


class CostSummary(ModelBase):
    food: float | None = None
    entertainment: float | None = None
    transport: float | None = None
    total: float


class ItineraryResponse(ModelBase):
    destination: str
    duration_days: int
    days: list[DayPlan]
    cost_summary: CostSummary
    generated_at: str
