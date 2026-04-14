"""NomadAgent API — FastAPI entry point."""

from fastapi import FastAPI

app = FastAPI(
    title="NomadAgent API",
    version="0.1.0",
    docs_url="/docs",
)


@app.get("/api/v1/health")
async def health_check() -> dict[str, str]:
    """Health check endpoint."""
    return {"status": "ok"}
