import pytest

from src.agent.nodes.researcher import researcher_node
from src.agent.state import MAX_RESULTS_PER_TASK, MAX_SEARCH_ITERATIONS_PER_TASK, MAX_TAVILY_CALLS
from src.agent.tools.tavily_search import TavilySearchTool, TavilyUnavailableError


class FakeSearchTool:
    def __init__(self) -> None:
        self.calls: list[tuple[str, int]] = []

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        return [
            {"title": f"result-{index} for {query}", "url": f"https://example.com/{index}"}
            for index in range(MAX_RESULTS_PER_TASK)
        ]


class EmptyThenPopulatedSearchTool:
    def __init__(self) -> None:
        self.calls: list[tuple[str, int]] = []

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        if len(self.calls) == 1:
            return []
        return [
            {
                "title": f"Found result {index}",
                "url": f"https://example.com/found-{index}",
            }
            for index in range(MAX_RESULTS_PER_TASK)
        ]


class AlwaysEmptySearchTool:
    def __init__(self) -> None:
        self.calls: list[tuple[str, int]] = []

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        return []


class SuccessThenUnavailableSearchTool:
    def __init__(self) -> None:
        self.calls_made = 0

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls_made += 1
        if self.calls_made == 1:
            return [{"title": "Found", "url": "https://example.com/found"}]
        raise TavilyUnavailableError("down")


class NonIntCallsMadeSearchTool:
    calls_made = "invalid"

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        return [
            {"title": f"result-{index} for {query}", "url": f"https://example.com/{index}"}
            for index in range(MAX_RESULTS_PER_TASK)
        ]


class FlakyTavilyClient:
    def __init__(self) -> None:
        self.calls = 0

    def search(self, query: str, **kwargs: object) -> dict[str, object]:
        self.calls += 1
        if self.calls == 1:
            raise RuntimeError("temporary network issue")
        return {
            "results": [
                {"title": "Stable Result", "url": "https://example.com/stable"},
                {"title": "Stable Result 2", "url": "https://example.com/stable-2"},
                {"title": "Stable Result 3", "url": "https://example.com/stable-3"},
            ]
        }


@pytest.mark.asyncio
async def test_researcher_executes_one_search_per_task_and_stores_results() -> None:
    search_tool = FakeSearchTool()
    state = {
        "prompt": "3 days in lisbon",
        "destination": "Lisbon",
        "duration_days": 3,
        "interest_categories": ["food", "culture"],
        "tasks": [
            {"name": "Local Research", "query": "q1"},
            {"name": "Event Checking", "query": "q2"},
            {"name": "Route Optimization", "query": "q3"},
        ],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) == 3
    assert all(max_results == MAX_RESULTS_PER_TASK for _, max_results in search_tool.calls)
    assert set(result["task_results"].keys()) == {
        "Local Research",
        "Event Checking",
        "Route Optimization",
    }
    assert result["tavily_calls_made"] == 3


@pytest.mark.asyncio
async def test_researcher_self_corrects_and_emits_event_on_empty_results() -> None:
    search_tool = EmptyThenPopulatedSearchTool()
    state = {
        "prompt": "trip",
        "destination": "Ella",
        "duration_days": 2,
        "interest_categories": ["nature"],
        "tasks": [{"name": "Things To Do", "query": "hidden waterfalls with opening hours"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) == 2
    assert result["task_results"]["Things To Do"]
    assert result["events"]
    event = next(
        item for item in result["events"] if item.get("event_type") == "self_correction"
    )
    assert event["data"]["original_query"] == "hidden waterfalls with opening hours"
    assert event["data"]["broadened_query"] != event["data"]["original_query"]
    assert event["data"]["reason"] == "zero_results"


@pytest.mark.asyncio
async def test_researcher_respects_call_budget() -> None:
    search_tool = FakeSearchTool()
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [{"name": f"Task {index}", "query": f"q{index}"} for index in range(20)],
        "tavily_calls_made": MAX_TAVILY_CALLS,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert result["tavily_calls_made"] == MAX_TAVILY_CALLS
    assert result["task_results"] == {}
    assert search_tool.calls == []


@pytest.mark.asyncio
async def test_researcher_enforces_iteration_cap_and_global_budget() -> None:
    search_tool = AlwaysEmptySearchTool()
    state = {
        "prompt": "trip",
        "destination": "Nuwara Eliya",
        "duration_days": 2,
        "interest_categories": ["nature"],
        "tasks": [{"name": "Local Research", "query": "best tea estates"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) <= MAX_SEARCH_ITERATIONS_PER_TASK
    assert result["tavily_calls_made"] <= MAX_TAVILY_CALLS


@pytest.mark.asyncio
async def test_researcher_handles_tavily_retry_via_search_tool() -> None:
    flaky_client = FlakyTavilyClient()
    search_tool = TavilySearchTool(client=flaky_client)
    state = {
        "prompt": "trip",
        "destination": "Kandy",
        "duration_days": 2,
        "interest_categories": ["history"],
        "tasks": [{"name": "Local Research", "query": "best historical sites"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert flaky_client.calls == 2
    assert result["task_results"]["Local Research"]
    assert result["tavily_calls_made"] >= 2


@pytest.mark.asyncio
async def test_researcher_marks_best_results_unverified_after_tavily_unavailable() -> None:
    search_tool = SuccessThenUnavailableSearchTool()
    state = {
        "prompt": "trip",
        "destination": "Kandy",
        "duration_days": 2,
        "interest_categories": ["history"],
        "tasks": [{"name": "Local Research", "query": "hidden temples with opening hours"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    entries = result["task_results"]["Local Research"]
    assert entries
    assert entries[0]["_degraded_unverified"] is True
    assert result["events"]
    assert any(event["event_type"] == "error" for event in result["events"])


@pytest.mark.asyncio
async def test_researcher_handles_non_int_calls_made_counter() -> None:
    search_tool = NonIntCallsMadeSearchTool()
    state = {
        "prompt": "trip",
        "destination": "Kandy",
        "duration_days": 2,
        "interest_categories": ["history"],
        "tasks": [{"name": "Local Research", "query": "best historical sites"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert result["task_results"]["Local Research"]
    assert result["tavily_calls_made"] == 1


def test_researcher_declares_iteration_cap_constant() -> None:
    assert MAX_SEARCH_ITERATIONS_PER_TASK == 5
