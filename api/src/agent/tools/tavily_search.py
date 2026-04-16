from __future__ import annotations

from collections.abc import Sequence
from typing import Any


class TavilySearchTool:
    """Thin wrapper around Tavily client calls for testability."""

    async def search(self, query: str, *, max_results: int) -> Sequence[dict[str, Any]]:
        raise NotImplementedError("Tavily wrapper will be implemented in Task 4")
