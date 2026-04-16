from __future__ import annotations

from src.agent.state import AgentState


async def planner_node(state: AgentState) -> AgentState:
    """Parse prompt and create research tasks for downstream execution."""
    raise NotImplementedError("Planner node will be implemented in Task 3")
