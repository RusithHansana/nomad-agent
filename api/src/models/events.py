from pydantic import BaseModel


class SSEEvent(BaseModel):
    event_type: str
    timestamp: str
    data: dict[str, object]

    @classmethod
    def from_payload(cls, payload: dict[str, object]) -> "SSEEvent":
        return cls.model_validate(payload)

    def to_payload(self) -> dict[str, object]:
        return self.model_dump()
