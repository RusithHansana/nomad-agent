import pytest

from src.agent.state import MAX_RESULTS_PER_TASK, MAX_TAVILY_CALLS
from src.agent.tools.tavily_search import (
    TavilyCallLimitExceededError,
    TavilySearchTool,
)


class FakeTavilyClient:
    def __init__(self, payload: dict[str, object]) -> None:
        self.payload = payload
        self.calls: list[dict[str, object]] = []

    def search(self, query: str, **kwargs: object) -> dict[str, object]:
        self.calls.append({"query": query, **kwargs})
        return self.payload


@pytest.mark.asyncio
async def test_tavily_search_enforces_top_result_limit() -> None:
    client = FakeTavilyClient(payload={"results": [{"title": "A"}]})
    tool = TavilySearchTool(client=client)

    await tool.search("best museums in lisbon", max_results=20)

    assert len(client.calls) == 1
    assert client.calls[0]["max_results"] == MAX_RESULTS_PER_TASK


@pytest.mark.asyncio
async def test_tavily_search_enforces_total_call_budget() -> None:
    client = FakeTavilyClient(payload={"results": []})
    tool = TavilySearchTool(client=client)

    for index in range(MAX_TAVILY_CALLS):
        await tool.search(f"query-{index}", max_results=1)

    with pytest.raises(TavilyCallLimitExceededError):
        await tool.search("query-over-budget", max_results=1)


@pytest.mark.asyncio
async def test_tavily_search_sanitizes_text_fields() -> None:
    client = FakeTavilyClient(
        payload={
            "results": [
                {
                    "title": "Best <script>Place</script>\x00",
                    "content": "Open > 10pm\x1f",
                    "raw_content": "Address <Main St>",
                }
            ]
        }
    )
    tool = TavilySearchTool(client=client)

    results = await tool.search("nightlife", max_results=3)

    assert results[0]["title"] == "Best &lt;script&gt;Place&lt;/script&gt;"
    assert results[0]["content"] == "Open &gt; 10pm"
    assert results[0]["raw_content"] == "Address &lt;Main St&gt;"
