import pytest

from src.agent.nodes.researcher import researcher_node
from src.agent.state import MAX_RESULTS_PER_TASK
from src.agent.state import MAX_SEARCH_ITERATIONS_PER_TASK
from src.agent.state import MAX_TAVILY_CALLS


class FakeSearchTool:
    def __init__(self) -> None:
        self.calls: list[tuple[str, int]] = []

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        return [{"title": f"result for {query}"}]


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
async def test_researcher_respects_call_budget() -> None:
    search_tool = FakeSearchTool()
    state = {
        "prompt": "trip",
        "destination": "Lisbon",
        "duration_days": 1,
        "interest_categories": ["food"],
        "tasks": [{"name": f"Task {index}", "query": f"q{index}"} for index in range(20)],
        "tavily_calls_made": MAX_TAVILY_CALLS,
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert result["tavily_calls_made"] == MAX_TAVILY_CALLS
    assert result["task_results"] == {}
    assert search_tool.calls == []


def test_researcher_declares_iteration_cap_constant() -> None:
    assert MAX_SEARCH_ITERATIONS_PER_TASK == 5
