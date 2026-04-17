import json

import pytest
from httpx import ASGITransport, AsyncClient

from src.main import create_app


def _parse_sse_payloads(raw_body: str) -> list[dict[str, object]]:
    payloads: list[dict[str, object]] = []
    for block in raw_body.split("\n\n"):
        data_lines = [line for line in block.splitlines() if line.startswith("data:")]
        for line in data_lines:
            raw_payload = line.removeprefix("data:").strip()
            if not raw_payload:
                continue
            payloads.append(json.loads(raw_payload))
    return payloads


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

    async def _fake_stream_itinerary_events(_: str):
        yield {
            "event_type": "thought_log",
            "timestamp": "2026-04-17T00:00:00+00:00",
            "data": {"message": "Starting research...", "step": "start"},
        }
        yield {
            "event_type": "itinerary_complete",
            "timestamp": "2026-04-17T00:00:01+00:00",
            "data": {
                "itinerary": {
                    "destination": "Lisbon",
                    "duration_days": 1,
                    "days": [{"day_number": 1, "venues": []}],
                    "cost_summary": {"total": 0.0},
                    "generated_at": "2026-04-16T00:00:00+00:00",
                }
            },
        }

    monkeypatch.setattr(
        "src.api.router.stream_itinerary_events",
        _fake_stream_itinerary_events,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        async with client.stream(
            "POST",
            "/api/v1/generate",
            json={"prompt": "trip to lisbon"},
            headers={"X-API-Key": "test-key"},
        ) as response:
            assert response.status_code == 200
            assert response.headers["content-type"].startswith("text/event-stream")
            body = ""
            async for chunk in response.aiter_text():
                body += chunk

    payloads = _parse_sse_payloads(body)
    assert payloads
    assert payloads[-1]["event_type"] == "itinerary_complete"
    assert payloads[-1]["data"]["itinerary"]["destination"] == "Lisbon"


@pytest.mark.parametrize(
    ("code", "message"),
    [
        ("INVALID_PROMPT", "Prompt not allowed"),
        ("TAVILY_UNAVAILABLE", "Tavily unavailable"),
        ("GENERATION_TIMEOUT", "Generation timed out"),
    ],
)
@pytest.mark.asyncio
async def test_generate_streams_error_events_for_authenticated_requests(
    monkeypatch: pytest.MonkeyPatch,
    code: str,
    message: str,
) -> None:
    monkeypatch.setenv("APP_API_KEY", "test-key")

    async def _fake_stream_itinerary_events(_: str):
        yield {
            "event_type": "error",
            "timestamp": "2026-04-17T00:00:00+00:00",
            "data": {
                "code": code,
                "message": message,
                "details": {},
            },
        }

    monkeypatch.setattr(
        "src.api.router.stream_itinerary_events",
        _fake_stream_itinerary_events,
    )

    app = create_app()
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as client:
        async with client.stream(
            "POST",
            "/api/v1/generate",
            json={"prompt": "trip prompt"},
            headers={"X-API-Key": "test-key"},
        ) as response:
            assert response.status_code == 200
            assert response.headers["content-type"].startswith("text/event-stream")
            body = ""
            async for chunk in response.aiter_text():
                body += chunk

    payloads = _parse_sse_payloads(body)
    assert payloads == [
        {
            "event_type": "error",
            "timestamp": "2026-04-17T00:00:00+00:00",
            "data": {
                "code": code,
                "message": message,
                "details": {},
            },
        }
    ]
