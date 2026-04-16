from __future__ import annotations

from typing import TypedDict

MAX_TASKS = 3
MAX_RESULTS_PER_TASK = 3
MAX_TAVILY_CALLS = 9
GENERATION_TIMEOUT_SECONDS = 30
MAX_SEARCH_ITERATIONS_PER_TASK = 5


class ResearchTask(TypedDict):
    """Represents a single research task and its generated query."""

    name: str
    query: str


class AgentState(TypedDict):
    """Mutable state passed through the LangGraph workflow."""

    prompt: str
    destination: str
    duration_days: int
    interest_categories: list[str]
    tasks: list[ResearchTask]
    tavily_calls_made: int
    task_results: dict[str, list[dict[str, object]]]
    error_event: dict[str, object] | None
