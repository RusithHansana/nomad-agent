from __future__ import annotations

import logging
import re
from datetime import UTC, datetime
from typing import Any

from src.agent.state import (
    MAX_RESULTS_PER_TASK,
    MAX_SEARCH_ITERATIONS_PER_TASK,
    MAX_TAVILY_CALLS,
    AgentState,
    append_event_to_buffer,
    get_event_buffer,
)
from src.agent.tools.tavily_search import (
    TavilyCallLimitExceededError,
    TavilySearchTool,
    TavilyUnavailableError,
)
from src.models.events import (
    ErrorData,
    ErrorEvent,
    SelfCorrectionData,
    SelfCorrectionEvent,
    ThoughtLogData,
    ThoughtLogEvent,
)

logger = logging.getLogger(__name__)

MAX_DESTINATION_LENGTH = 120
MAX_TASK_NAME_LENGTH = 80
MAX_QUERY_LENGTH = 240
RELEVANCE_THRESHOLD = 0.4


def _as_float_safe(value: object, default: float = 0.0) -> float:
    """Safely coerce a value to float."""
    if not isinstance(value, (int, float, str)):
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _compute_relevance_score(
    result: dict[str, object],
    destination: str,
) -> float:
    """Hybrid relevance: Tavily confidence + destination keyword match."""
    tavily_score = _as_float_safe(result.get("score"), default=0.0)
    # Tavily component: 50% of total weight
    tavily_component = min(max(tavily_score, 0.0), 1.0) * 0.5

    dest_lower = destination.lower().strip()
    dest_words = [w for w in dest_lower.split() if len(w) > 2]

    title = str(result.get("title") or "").lower()
    url = str(result.get("url") or "").lower()
    content_snippet = str(result.get("content") or "")[:500].lower()
    searchable = f"{title} {url} {content_snippet}"

    # Destination component: 50% of total weight
    if dest_lower in searchable:
        destination_component = 0.5  # full destination string found
    elif any(word in searchable for word in dest_words):
        destination_component = 0.3  # partial match (at least one word)
    else:
        destination_component = 0.0  # no destination signal at all

    return tavily_component + destination_component


def _normalize_text(value: str, *, max_length: int) -> str:
    normalized = re.sub(r"\s+", " ", value).strip()
    return normalized[:max_length].strip()


def _normalize_query(value: object) -> str:
    if not isinstance(value, str):
        return ""
    return _normalize_text(value, max_length=MAX_QUERY_LENGTH)


def _normalize_task_name(value: object, *, fallback: str) -> str:
    if not isinstance(value, str):
        return fallback
    normalized = _normalize_text(value, max_length=MAX_TASK_NAME_LENGTH)
    return normalized or fallback


def _build_tavily_unavailable_event(task_name: str) -> dict[str, object]:
    event = ErrorEvent(
        timestamp=datetime.now(UTC).isoformat(),
        data=ErrorData(
            code="TAVILY_UNAVAILABLE",
            message="Research services are temporarily unavailable. Please try again shortly.",
            details={"task": task_name},
        ),
    )
    return event.to_payload()


def _missing_identifiers_count(results: list[dict[str, object]]) -> int:
    missing_count = 0
    for item in results:
        has_name = bool(str(item.get("title") or item.get("name") or "").strip())
        has_url = bool(str(item.get("url") or item.get("source_url") or "").strip())
        if not has_name and not has_url:
            missing_count += 1
    return missing_count


def _is_insufficient_result_set(results: list[dict[str, object]]) -> tuple[bool, str]:
    if not results:
        return True, "zero_results"
    if len(results) < MAX_RESULTS_PER_TASK:
        return True, "insufficient_results"
    if _missing_identifiers_count(results) == len(results):
        return True, "insufficient_results"
    return False, ""


def _remove_specific_constraints(query: str) -> str:
    normalized = re.sub(
        r"\b(with\s+)?(opening\s*hours?|price\s*range|cost\s*range|budget)\b",
        "",
        query,
        flags=re.IGNORECASE,
    )
    normalized = re.sub(r"\s+", " ", normalized).strip(" ,")
    return normalized or query.strip()


def _fallback_broadened_query(task_name: str, destination: str) -> str:
    lowered_task = task_name.lower()
    if "food" in lowered_task or "restaurant" in lowered_task or "dining" in lowered_task:
        return f"best restaurants in and around {destination}".strip()
    if "activity" in lowered_task or "attraction" in lowered_task or "things" in lowered_task:
        return f"top things to do in and around {destination}".strip()
    return f"popular places in and around {destination}".strip()


def _safe_int(value: object, fallback: int) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return fallback


def _mark_results_unverified(results: list[dict[str, object]]) -> list[dict[str, object]]:
    marked: list[dict[str, object]] = []
    for item in results:
        updated_item = dict(item)
        updated_item["_degraded_unverified"] = True
        marked.append(updated_item)
    return marked


def _broaden_query(query: str, task_name: str, destination: str) -> str:
    cleaned_query = _remove_specific_constraints(query)
    if (
        cleaned_query
        and cleaned_query != query
        and "around" not in cleaned_query.lower()
        and destination.strip()
    ):
        return f"{cleaned_query} in and around {destination}".strip()

    if cleaned_query and cleaned_query != query:
        return cleaned_query

    if cleaned_query and "around" not in cleaned_query.lower() and destination.strip():
        return f"{cleaned_query} in and around {destination}".strip()

    return _fallback_broadened_query(task_name=task_name, destination=destination)


async def researcher_node(
    state: AgentState,
    *,
    search_tool: TavilySearchTool | Any | None = None,
) -> AgentState:
    """Execute research tasks and attach Tavily results to state."""
    if state.get("error_event") is not None:
        return state

    tool = search_tool or TavilySearchTool()
    current_calls = _safe_int(state.get("tavily_calls_made", 0), 0)
    events, event_cursor, event_base_cursor = get_event_buffer(state)

    raw_task_results = state.get("task_results", {})
    task_results = dict(raw_task_results) if isinstance(raw_task_results, dict) else {}

    tasks = state.get("tasks", [])
    task_list = tasks if isinstance(tasks, list) else []
    destination = _normalize_text(
        str(state.get("destination", "")),
        max_length=MAX_DESTINATION_LENGTH,
    )

    for index, task in enumerate(task_list, start=1):
        if current_calls >= MAX_TAVILY_CALLS:
            break

        fallback_task_name = f"Task {index}"
        if not isinstance(task, dict):
            task_results[fallback_task_name] = []
            continue

        task_name = _normalize_task_name(task.get("name"), fallback=fallback_task_name)
        query = _normalize_query(task.get("query", ""))
        if not query:
            task_results[task_name] = []
            continue

        results_for_task: list[dict[str, object]] = []
        best_results_for_task: list[dict[str, object]] = []
        attempted_queries: set[str] = set()
        current_query = query

        for _ in range(MAX_SEARCH_ITERATIONS_PER_TASK):
            if current_calls >= MAX_TAVILY_CALLS:
                break

            if current_query in attempted_queries:
                break
            attempted_queries.add(current_query)

            events, event_cursor, event_base_cursor = append_event_to_buffer(
                events=events,
                event_cursor=event_cursor,
                event_base_cursor=event_base_cursor,
                payload=ThoughtLogEvent(
                    timestamp=datetime.now(UTC).isoformat(),
                    data=ThoughtLogData(
                        message=f"Searching {task_name}",
                        step="researcher",
                    ),
                ).to_payload(),
            )

            previous_tool_calls = _safe_int(
                getattr(tool, "calls_made", current_calls),
                current_calls,
            )

            try:
                results = await tool.search(current_query, max_results=MAX_RESULTS_PER_TASK)
            except TavilyCallLimitExceededError:
                current_calls = MAX_TAVILY_CALLS
                break
            except TavilyUnavailableError:
                latest_tool_calls = _safe_int(
                    getattr(tool, "calls_made", previous_tool_calls),
                    previous_tool_calls,
                )
                call_increment = latest_tool_calls - previous_tool_calls
                if call_increment <= 0:
                    call_increment = 1
                current_calls = min(MAX_TAVILY_CALLS, current_calls + call_increment)

                if best_results_for_task:
                    best_results_for_task = _mark_results_unverified(best_results_for_task)

                events, event_cursor, event_base_cursor = append_event_to_buffer(
                    events=events,
                    event_cursor=event_cursor,
                    event_base_cursor=event_base_cursor,
                    payload=_build_tavily_unavailable_event(task_name),
                )
                results_for_task = []
                break

            latest_tool_calls = _safe_int(
                getattr(tool, "calls_made", previous_tool_calls + 1),
                previous_tool_calls + 1,
            )
            call_increment = latest_tool_calls - previous_tool_calls
            if call_increment <= 0:
                call_increment = 1
            current_calls = min(MAX_TAVILY_CALLS, current_calls + call_increment)

            results_for_task = [
                item for item in results[:MAX_RESULTS_PER_TASK] if isinstance(item, dict)
            ]

            # Tag each result with the query used (for debug dumps)
            for item in results_for_task:
                item["_search_query"] = current_query

            # Apply hybrid relevance filtering
            scored_results: list[dict[str, object]] = []
            for item in results_for_task:
                score = _compute_relevance_score(item, destination)
                item["_relevance_score"] = score
                if score >= RELEVANCE_THRESHOLD:
                    scored_results.append(item)

            if not scored_results and results_for_task:
                # All results below threshold — flag entire batch as degraded
                scored_results = _mark_results_unverified(results_for_task)
                logger.warning(
                    "All results for task '%s' scored below relevance threshold "
                    "(%.2f). Marking as degraded.",
                    task_name,
                    RELEVANCE_THRESHOLD,
                )

            results_for_task = scored_results

            if len(results_for_task) > len(best_results_for_task):
                best_results_for_task = results_for_task

            is_insufficient, reason = _is_insufficient_result_set(results_for_task)
            if not is_insufficient:
                break

            broadened_query = _broaden_query(
                query=current_query,
                task_name=task_name,
                destination=destination,
            )
            if not broadened_query or broadened_query == current_query:
                break

            event = SelfCorrectionEvent(
                timestamp=datetime.now(UTC).isoformat(),
                data=SelfCorrectionData(
                    original_query=current_query,
                    broadened_query=broadened_query,
                    reason=reason,
                ),
            )
            events, event_cursor, event_base_cursor = append_event_to_buffer(
                events=events,
                event_cursor=event_cursor,
                event_base_cursor=event_base_cursor,
                payload=event.to_payload(),
            )
            current_query = broadened_query

        task_results[task_name] = best_results_for_task or results_for_task
        events, event_cursor, event_base_cursor = append_event_to_buffer(
            events=events,
            event_cursor=event_cursor,
            event_base_cursor=event_base_cursor,
            payload=ThoughtLogEvent(
                timestamp=datetime.now(UTC).isoformat(),
                data=ThoughtLogData(
                    message=f"Found {len(task_results[task_name])} results for {task_name}",
                    step="researcher",
                ),
            ).to_payload(),
        )

    return {
        **state,
        "event_cursor": event_cursor,
        "event_base_cursor": event_base_cursor,
        "events": events,
        "task_results": task_results,
        "tavily_calls_made": current_calls,
    }
