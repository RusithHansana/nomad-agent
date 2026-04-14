import pytest
from httpx import ASGITransport, AsyncClient

from src.main import create_app


@pytest.mark.asyncio
async def test_health_check_returns_ok() -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


@pytest.mark.asyncio
async def test_generate_requires_api_key() -> None:
    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post("/api/v1/generate", json={"prompt": "trip to japan"})

    assert response.status_code == 401
    assert response.json() == {
        "error": "Invalid or missing API key",
        "code": "INVALID_API_KEY",
        "details": {},
    }
