"""NomadAgent API - FastAPI entry point."""

import logging

from fastapi import FastAPI

from src.api.middleware import apply_middleware
from src.api.router import router
from src.config import get_settings


def create_app() -> FastAPI:
    settings = get_settings()
    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
    )

    app = FastAPI(
        title="NomadAgent API",
        version="0.1.0",
        docs_url="/docs",
    )
    apply_middleware(app)
    app.include_router(router)
    return app


app = create_app()
