from fastapi import APIRouter, Depends, HTTPException

from src.api.dependencies import validate_api_key
from src.models.request import PromptRequest
from src.services.generation import GenerationPipelineError
from src.services.generation import GenerationTimeoutError
from src.services.generation import InvalidPromptError
from src.services.generation import TavilyUnavailableServiceError
from src.services.generation import generate_itinerary_response

router = APIRouter(prefix="/api/v1")


@router.get("/health")
async def health_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/generate", dependencies=[Depends(validate_api_key)])
async def generate_itinerary(request: PromptRequest) -> dict[str, object]:
    try:
        return await generate_itinerary_response(request.prompt)
    except InvalidPromptError as exc:
        raise HTTPException(
            status_code=400,
            detail={
                "error": str(exc) or "Prompt is not allowed",
                "code": "INVALID_PROMPT",
                "details": {},
            },
        ) from exc
    except TavilyUnavailableServiceError as exc:
        raise HTTPException(
            status_code=503,
            detail={
                "error": str(exc) or "Research service unavailable",
                "code": "TAVILY_UNAVAILABLE",
                "details": {},
            },
        ) from exc
    except GenerationTimeoutError as exc:
        raise HTTPException(
            status_code=504,
            detail={
                "error": str(exc) or "Generation timed out",
                "code": "GENERATION_TIMEOUT",
                "details": {},
            },
        ) from exc
    except GenerationPipelineError as exc:
        raise HTTPException(
            status_code=500,
            detail={
                "error": str(exc) or "Generation failed",
                "code": "GENERATION_FAILED",
                "details": {},
            },
        ) from exc
