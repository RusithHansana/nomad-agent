from __future__ import annotations

import asyncio
import html
import re
from collections.abc import Sequence
from typing import Any

from src.agent.state import MAX_RESULTS_PER_TASK
from src.agent.state import MAX_TAVILY_CALLS
from src.config import get_settings


class TavilyUnavailableError(RuntimeError):
    """Raised when Tavily cannot be called due to config or API failures."""


class TavilyCallLimitExceededError(RuntimeError):
    """Raised when Tavily call budget is exhausted for a single itinerary."""


def sanitize_text(value: str) -> str:
    """Normalize text for safe downstream rendering and storage."""
    without_controls = re.sub(r"[\x00-\x1f\x7f]", "", value)
    escaped = html.escape(without_controls, quote=False)
    return escaped.strip()


def _sanitize_payload(value: object) -> object:
    if isinstance(value, str):
        return sanitize_text(value)
    if isinstance(value, dict):
        return {sanitize_text(key): _sanitize_payload(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_sanitize_payload(item) for item in value]
    return value


class TavilySearchTool:
    """Thin wrapper around Tavily client calls for testability."""

    def __init__(
        self,
        *,
        client: Any | None = None,
        max_total_calls: int = MAX_TAVILY_CALLS,
    ) -> None:
        self._client = client
        self._max_total_calls = max_total_calls
        self._calls_made = 0

    @property
    def calls_made(self) -> int:
        return self._calls_made

    def _get_client(self) -> Any:
        if self._client is not None:
            return self._client

        settings = get_settings()
        if not settings.tavily_api_key:
            raise TavilyUnavailableError("Tavily API key is not configured")

        try:
            from tavily import TavilyClient
        except Exception as exc:  # pragma: no cover - import failure is environment-specific
            raise TavilyUnavailableError("Tavily client is unavailable") from exc

        self._client = TavilyClient(api_key=settings.tavily_api_key)
        return self._client

    async def search(self, query: str, *, max_results: int) -> Sequence[dict[str, Any]]:
        if self._calls_made >= self._max_total_calls:
            raise TavilyCallLimitExceededError("Maximum Tavily call budget reached")

        requested_results = max(1, min(max_results, MAX_RESULTS_PER_TASK))
        client = self._get_client()

        def _run_search() -> dict[str, Any]:
            return client.search(
                query=query,
                max_results=requested_results,
                include_answer=False,
                include_raw_content=True,
            )

        try:
            response = await asyncio.to_thread(_run_search)
        except Exception as exc:
            raise TavilyUnavailableError("Tavily search failed") from exc

        self._calls_made += 1
        raw_results = response.get("results", [])
        if not isinstance(raw_results, list):
            return []

        sanitized_results: list[dict[str, Any]] = []
        for item in raw_results[:requested_results]:
            if isinstance(item, dict):
                sanitized_item = _sanitize_payload(item)
                if isinstance(sanitized_item, dict):
                    sanitized_results.append(sanitized_item)
        return sanitized_results
