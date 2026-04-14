from fastapi import Header, HTTPException

from src.config import get_settings


def _api_key_error() -> HTTPException:
    return HTTPException(
        status_code=401,
        detail={
            "error": "Invalid or missing API key",
            "code": "INVALID_API_KEY",
            "details": {},
        },
    )


async def validate_api_key(x_api_key: str | None = Header(default=None, alias="X-API-Key")) -> None:
    settings = get_settings()
    if x_api_key != settings.app_api_key:
        raise _api_key_error()
