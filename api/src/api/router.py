from fastapi import APIRouter, Depends, HTTPException

from src.api.dependencies import validate_api_key
from src.models.request import PromptRequest

router = APIRouter(prefix="/api/v1")


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/generate", dependencies=[Depends(validate_api_key)])
async def generate_itinerary(_: PromptRequest) -> dict[str, object]:
    raise HTTPException(
        status_code=501,
        detail={
            "error": "Generate endpoint is not implemented yet",
            "code": "NOT_IMPLEMENTED",
            "details": {},
        },
    )
