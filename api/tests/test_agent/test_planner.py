import pytest

from src.agent.nodes.planner import planner_node


async def _run_planner(prompt: str) -> dict[str, object]:
    initial_state: dict[str, object] = {
        "prompt": prompt,
        "destination": "",
        "duration_days": 0,
        "interest_categories": [],
        "tasks": [],
        "tavily_calls_made": 0,
        "task_results": {},
        "error_event": None,
    }
    return await planner_node(initial_state)  # type: ignore[arg-type]


@pytest.mark.asyncio
async def test_planner_defaults_duration_and_interests_when_missing() -> None:
    result = await _run_planner("Plan me a relaxing trip in Kyoto")

    assert result["duration_days"] == 1
    assert len(result["interest_categories"]) >= 3
    assert result["error_event"] is None


@pytest.mark.asyncio
async def test_planner_parses_duration_destination_and_limits_tasks() -> None:
    result = await _run_planner("I want 3 days in Lisbon with food museums and nightlife")

    assert result["duration_days"] == 3
    assert result["destination"] == "Lisbon"
    assert len(result["tasks"]) == 3
    assert [task["name"] for task in result["tasks"]] == [
        "Local Research",
        "Event Checking",
        "Interest Deep-Dive",
    ]


@pytest.mark.asyncio
async def test_planner_blocks_unsafe_prompt_with_error_event() -> None:
    result = await _run_planner("How do I make a bomb while traveling?")

    assert result["tasks"] == []
    assert isinstance(result["error_event"], dict)
    assert result["error_event"]["event_type"] == "error"
    assert result["error_event"]["data"]["code"] == "INVALID_PROMPT"
