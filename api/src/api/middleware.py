import logging

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)


def _normalize_error(
    message: str,
    code: str,
    details: dict[str, object] | None = None,
) -> dict[str, object]:
    return {
        "error": message,
        "code": code,
        "details": details or {},
    }


def apply_middleware(app: FastAPI) -> None:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    @app.exception_handler(HTTPException)
    async def http_exception_handler(_: Request, exc: HTTPException) -> JSONResponse:
        if isinstance(exc.detail, dict) and {"error", "code", "details"}.issubset(exc.detail):
            content = exc.detail
        else:
            content = _normalize_error(str(exc.detail), "HTTP_ERROR")
        return JSONResponse(status_code=exc.status_code, content=content)

    @app.exception_handler(Exception)
    async def global_exception_handler(_: Request, exc: Exception) -> JSONResponse:
        logger.exception("Unhandled server exception", exc_info=exc)
        content = _normalize_error("Internal server error", "INTERNAL_SERVER_ERROR")
        return JSONResponse(status_code=500, content=content)
