from pydantic import BaseModel


class PromptRequest(BaseModel):
    prompt: str

    @classmethod
    def from_payload(cls, payload: dict[str, object]) -> "PromptRequest":
        return cls.model_validate(payload)

    def to_payload(self) -> dict[str, object]:
        return self.model_dump()
