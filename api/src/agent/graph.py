from __future__ import annotations

from langgraph.graph.state import CompiledStateGraph

from src.agent.state import AgentState


def build_graph() -> CompiledStateGraph:
    """Build and compile the planner -> researcher -> extractor -> compiler graph."""
    from langgraph.graph import END, START, StateGraph

    from src.agent.nodes.compiler import compiler_node
    from src.agent.nodes.extractor import extractor_node, pre_extractor_node
    from src.agent.nodes.planner import planner_node
    from src.agent.nodes.researcher import researcher_node

    graph = StateGraph(AgentState)
    graph.add_node("planner", planner_node)
    graph.add_node("researcher", researcher_node)
    graph.add_node("pre_extractor", pre_extractor_node)
    graph.add_node("extractor", extractor_node)
    graph.add_node("compiler", compiler_node)

    graph.add_edge(START, "planner")
    graph.add_edge("planner", "researcher")
    graph.add_edge("researcher", "pre_extractor")
    graph.add_edge("pre_extractor", "extractor")
    graph.add_edge("extractor", "compiler")
    graph.add_edge("compiler", END)

    return graph.compile()
