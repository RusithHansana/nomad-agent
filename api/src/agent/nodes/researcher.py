from __future__ import annotations

from typing import Any

from src.agent.state import AgentState
from src.agent.state import MAX_RESULTS_PER_TASK
from src.agent.state import MAX_SEARCH_ITERATIONS_PER_TASK
from src.agent.state import MAX_TAVILY_CALLS
from src.agent.tools.tavily_search import TavilyCallLimitExceededError
from src.agent.tools.tavily_search import TavilySearchTool
from src.agent.tools.tavily_search import TavilyUnavailableError


async def researcher_node(
    state: AgentState,
    *,
    search_tool: TavilySearchTool | Any | None = None,
) -> AgentState:
    """Execute research tasks and attach Tavily results to state."""
    if state.get("error_event") is not None:
        return state

    tool = search_tool or TavilySearchTool()
    current_calls = int(state.get("tavily_calls_made", 0))
    task_results = dict(state.get("task_results", {}))
    tasks = state.get("tasks", [])

    for task in tasks:
        if current_calls >= MAX_TAVILY_CALLS:
            break

        task_name = str(task.get("name", "Task")).strip() or "Task"
        query = str(task.get("query", "")).strip()
        if not query:
            task_results[task_name] = []
            continue

        results_for_task: list[dict[str, object]] = []
        max_iterations = min(1, MAX_SEARCH_ITERATIONS_PER_TASK)
        for _ in range(max_iterations):
            if current_calls >= MAX_TAVILY_CALLS:
                break

            try:
                results = await tool.search(query, max_results=MAX_RESULTS_PER_TASK)
            except (TavilyCallLimitExceededError, TavilyUnavailableError):
                results = []

            current_calls += 1
            results_for_task = [
                item
                for item in results[:MAX_RESULTS_PER_TASK]
                if isinstance(item, dict)
            ]
            break

        task_results[task_name] = results_for_task

    return {
        **state,
        "task_results": task_results,
        "tavily_calls_made": current_calls,
    }
