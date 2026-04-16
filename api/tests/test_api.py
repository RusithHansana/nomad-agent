import pytest
from httpx import ASGITransport, AsyncClient

from src.main import create_app
from src.services.generation import (
    GenerationTimeoutError,
    InvalidPromptError,
    TavilyUnavailableServiceError,
)


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


@pytest.mark.asyncio
async def test_generate_returns_itinerary_success(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_API_KEY", "test-key")

    async def _fake_generate_itinerary_response(_: str) -> dict[str, object]:
        return {
            "destination": "Lisbon",
            "duration_days": 1,
            "days": [{"day_number": 1, "venues": []}],
            "cost_summary": {"total": 0.0},
            "generated_at": "2026-04-16T00:00:00+00:00",
        }

    monkeypatch.setattr(
        "src.api.router.generate_itinerary_response",
        _fake_generate_itinerary_response,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/generate",
            json={"prompt": "trip to lisbon"},
            headers={"X-API-Key": "test-key"},
        )

    assert response.status_code == 200
    assert response.json()["destination"] == "Lisbon"


@pytest.mark.asyncio
async def test_generate_maps_invalid_prompt_to_http_400(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_API_KEY", "test-key")

    async def _fake_generate_itinerary_response(_: str) -> dict[str, object]:
        raise InvalidPromptError("Prompt not allowed")

    monkeypatch.setattr(
        "src.api.router.generate_itinerary_response",
        _fake_generate_itinerary_response,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/generate",
            json={"prompt": "unsafe prompt"},
            headers={"X-API-Key": "test-key"},
        )

    assert response.status_code == 400
    assert response.json() == {
        "error": "Prompt not allowed",
        "code": "INVALID_PROMPT",
        "details": {},
    }


@pytest.mark.asyncio
async def test_generate_maps_tavily_unavailable_to_http_503(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setenv("APP_API_KEY", "test-key")

    async def _fake_generate_itinerary_response(_: str) -> dict[str, object]:
        raise TavilyUnavailableServiceError("Tavily unavailable")

    monkeypatch.setattr(
        "src.api.router.generate_itinerary_response",
        _fake_generate_itinerary_response,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/generate",
            json={"prompt": "trip prompt"},
            headers={"X-API-Key": "test-key"},
        )

    assert response.status_code == 503
    assert response.json() == {
        "error": "Tavily unavailable",
        "code": "TAVILY_UNAVAILABLE",
        "details": {},
    }


@pytest.mark.asyncio
async def test_generate_maps_timeout_to_http_504(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_API_KEY", "test-key")

    async def _fake_generate_itinerary_response(_: str) -> dict[str, object]:
        raise GenerationTimeoutError("Generation timed out")

    monkeypatch.setattr(
        "src.api.router.generate_itinerary_response",
        _fake_generate_itinerary_response,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        response = await client.post(
            "/api/v1/generate",
            json={"prompt": "trip prompt"},
            headers={"X-API-Key": "test-key"},
        )

    assert response.status_code == 504
    assert response.json() == {
        "error": "Generation timed out",
        "code": "GENERATION_TIMEOUT",
        "details": {},
    }
