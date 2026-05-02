import pytest

from src.agent.nodes.researcher import (
    MAX_DESTINATION_LENGTH,
    MAX_QUERY_LENGTH,
    researcher_node,
)
from src.agent.state import MAX_RESULTS_PER_TASK, MAX_SEARCH_ITERATIONS_PER_TASK, MAX_TAVILY_CALLS
from src.agent.tools.tavily_search import TavilySearchTool, TavilyUnavailableError


class FakeSearchTool:
    def __init__(self, destination: str = "") -> None:
        self.calls: list[tuple[str, int]] = []
        self._destination = destination

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        dest = self._destination or "Lisbon"
        return [
            {
                "title": f"result-{index} for {query}",
                "url": f"https://example.com/{index}",
                "content": f"Great places in {dest}",
                "score": 0.9,
            }
            for index in range(MAX_RESULTS_PER_TASK)
        ]


class EmptyThenPopulatedSearchTool:
    def __init__(self, destination: str = "") -> None:
        self.calls: list[tuple[str, int]] = []
        self._destination = destination

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls.append((query, max_results))
        if len(self.calls) == 1:
            return []
        dest = self._destination or "Ella"
        return [
            {
                "title": f"Found result {index}",
                "url": f"https://example.com/found-{index}",
                "content": f"Attractions near {dest}",
                "score": 0.9,
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
            return [
                {
                    "title": "Found",
                    "url": "https://example.com/found",
                    "content": "Things to do in Kandy",
                    "score": 0.9,
                }
            ]
        raise TavilyUnavailableError("down")


class NonIntCallsMadeSearchTool:
    calls_made = "invalid"

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        return [
            {
                "title": f"result-{index} for {query}",
                "url": f"https://example.com/{index}",
                "content": "Visiting Kandy temples",
                "score": 0.9,
            }
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
                {"title": "Kandy Temple of Tooth", "url": "https://example.com/stable", "content": "Historic Kandy", "score": 0.9},
                {"title": "Kandy Lake", "url": "https://example.com/stable-2", "content": "Beautiful Kandy", "score": 0.85},
                {"title": "Kandy Market", "url": "https://example.com/stable-3", "content": "Shopping in Kandy", "score": 0.8},
            ]
        }


@pytest.mark.asyncio
async def test_researcher_executes_one_search_per_task_and_stores_results() -> None:
    search_tool = FakeSearchTool(destination="Lisbon")
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
    event = next(item for item in result["events"] if item.get("event_type") == "self_correction")
    assert event["data"]["original_query"] == "hidden waterfalls with opening hours"
    assert event["data"]["broadened_query"] != event["data"]["original_query"]
    assert event["data"]["reason"] == "zero_results"


@pytest.mark.asyncio
async def test_researcher_respects_call_budget() -> None:
    search_tool = FakeSearchTool(destination="Lisbon")
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


@pytest.mark.asyncio
async def test_researcher_handles_malformed_tasks_without_crashing() -> None:
    search_tool = FakeSearchTool(destination="Kandy")
    state = {
        "prompt": "trip",
        "destination": "Kandy",
        "duration_days": 2,
        "interest_categories": ["history"],
        "tasks": [
            {"name": "Local Research", "query": "best historical sites"},
            None,
            "unexpected",
            {"name": 123, "query": ["invalid"]},
        ],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) == 1
    assert result["task_results"]["Local Research"]
    assert result["task_results"]["Task 2"] == []
    assert result["task_results"]["Task 3"] == []
    assert result["task_results"]["Task 4"] == []


@pytest.mark.asyncio
async def test_researcher_caps_destination_length_when_broadening_queries() -> None:
    search_tool = EmptyThenPopulatedSearchTool()
    long_destination = "A" * (MAX_DESTINATION_LENGTH + 40)
    state = {
        "prompt": "trip",
        "destination": long_destination,
        "duration_days": 2,
        "interest_categories": ["nature"],
        "tasks": [{"name": "Things To Do", "query": "hidden waterfalls with opening hours"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) == 2
    capped_destination = "A" * MAX_DESTINATION_LENGTH
    assert capped_destination in search_tool.calls[1][0]
    assert ("A" * (MAX_DESTINATION_LENGTH + 1)) not in search_tool.calls[1][0]


@pytest.mark.asyncio
async def test_researcher_caps_query_length_before_search() -> None:
    search_tool = FakeSearchTool(destination="Kandy")
    state = {
        "prompt": "trip",
        "destination": "Kandy",
        "duration_days": 2,
        "interest_categories": ["history"],
        "tasks": [{"name": "Local Research", "query": "x" * (MAX_QUERY_LENGTH + 50)}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
    }

    await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    assert len(search_tool.calls) == 1
    assert search_tool.calls[0][0] == "x" * MAX_QUERY_LENGTH


def test_researcher_declares_iteration_cap_constant() -> None:
    assert MAX_SEARCH_ITERATIONS_PER_TASK == 5


class AlwaysUnavailableSearchTool:
    """Simulates Tavily being completely unreachable — every search raises TavilyUnavailableError."""

    def __init__(self) -> None:
        self.calls_made = 0

    async def search(self, query: str, *, max_results: int) -> list[dict[str, object]]:
        self.calls_made += 1
        raise TavilyUnavailableError("Tavily is completely down")


@pytest.mark.asyncio
async def test_researcher_sets_tavily_unavailable_flag_when_fully_unavailable() -> None:
    """Task 7.1 — When Tavily fails on first task with no prior results, sets tavily_unavailable=True."""
    search_tool = AlwaysUnavailableSearchTool()
    state = {
        "prompt": "3 days in Kandy",
        "destination": "Kandy",
        "duration_days": 3,
        "interest_categories": ["culture", "food"],
        "tasks": [
            {"name": "Local Research", "query": "restaurants in Kandy"},
            {"name": "Event Checking", "query": "events in Kandy"},
        ],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
        "tavily_unavailable": False,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    # Tavily completely unavailable — flag must be set
    assert result["tavily_unavailable"] is True
    # Only 1 search call made (failed on first task — remaining tasks skipped)
    assert search_tool.calls_made == 1
    # Must emit a thought_log degradation warning, NOT a terminal error event
    thought_log_events = [
        e for e in result["events"] if e.get("event_type") == "thought_log"
    ]
    degradation_events = [
        e for e in thought_log_events
        if "unavailable" in (e.get("data") or {}).get("message", "").lower()
    ]
    assert len(degradation_events) >= 1, "Expected at least one thought_log degradation event"
    # Must NOT emit a terminal error event
    error_events = [e for e in result["events"] if e.get("event_type") == "error"]
    assert len(error_events) == 0, "Full Tavily unavailability must not emit a terminal error event"


@pytest.mark.asyncio
async def test_researcher_thought_log_degradation_event_content() -> None:
    """Task 7.1 — The degradation thought_log event must include the ⚠️ icon and correct message."""
    search_tool = AlwaysUnavailableSearchTool()
    state = {
        "prompt": "trip to Colombo",
        "destination": "Colombo",
        "duration_days": 2,
        "interest_categories": ["food"],
        "tasks": [{"name": "Local Research", "query": "best restaurants Colombo"}],
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
        "tavily_unavailable": False,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    thought_log_events = [e for e in result["events"] if e.get("event_type") == "thought_log"]
    degradation_events = [
        e for e in thought_log_events
        if (e.get("data") or {}).get("icon") == "⚠️"
    ]
    assert len(degradation_events) >= 1
    msg = degradation_events[0]["data"]["message"]
    assert "unavailable" in msg.lower()
    assert "unverified" in msg.lower()


@pytest.mark.asyncio
async def test_researcher_skips_remaining_tasks_when_fully_unavailable() -> None:
    """Task 7.1 — When full Tavily unavailability detected, remaining tasks should be skipped."""
    search_tool = AlwaysUnavailableSearchTool()
    three_tasks = [
        {"name": "Local Research", "query": "q1"},
        {"name": "Event Checking", "query": "q2"},
        {"name": "Interest Deep-Dive", "query": "q3"},
    ]
    state = {
        "prompt": "trip",
        "destination": "Colombo",
        "duration_days": 2,
        "interest_categories": ["food"],
        "tasks": three_tasks,
        "tavily_calls_made": 0,
        "events": [],
        "task_results": {},
        "error_event": None,
        "tavily_unavailable": False,
    }

    result = await researcher_node(state, search_tool=search_tool)  # type: ignore[arg-type]

    # Only 1 Tavily call made despite 3 tasks
    assert search_tool.calls_made == 1
    assert result["tavily_unavailable"] is True

