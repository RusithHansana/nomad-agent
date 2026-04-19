from __future__ import annotations
from langgraph.graph.state import CompiledStateGraph

from src.agent.state import AgentState


def build_graph() -> CompiledStateGraph:
    """Build and compile the minimal planner -> researcher -> compiler graph."""
    from langgraph.graph import END, START, StateGraph

    from src.agent.nodes.compiler import compiler_node
    from src.agent.nodes.planner import planner_node
    from src.agent.nodes.researcher import researcher_node

    graph = StateGraph(AgentState)
    graph.add_node("planner", planner_node)
    graph.add_node("researcher", researcher_node)
    graph.add_node("compiler", compiler_node)

    graph.add_edge(START, "planner")
    graph.add_edge("planner", "researcher")
    graph.add_edge("researcher", "compiler")
    graph.add_edge("compiler", END)

    return graph.compile()
