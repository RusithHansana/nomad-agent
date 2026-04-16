from __future__ import annotations

import re
from datetime import UTC, datetime

from src.agent.state import MAX_TASKS, AgentState
from src.models.events import ErrorData, ErrorEvent

DEFAULT_INTEREST_CATEGORIES = ["food", "culture", "nature"]

UNSAFE_PROMPT_PATTERNS = [
    re.compile(r"\b(make|build|create)\s+(?:a\s+)?(?:bomb|explosive|weapon)\b", re.IGNORECASE),
    re.compile(r"\b(how\s+to\s+kill|murder|assassinat(e|ion)|violent\s+attack)\b", re.IGNORECASE),
    re.compile(
        r"\b(buy\s+illegal\s+drugs?|traffic\s+drugs?|fraud\s+scheme|steal\b)\b", re.IGNORECASE
    ),
    re.compile(
        r"\b(explicit\s+sexual|sexual\s+services|hate\s+crime|harass\s+someone)\b", re.IGNORECASE
    ),
]

INTEREST_KEYWORDS: dict[str, tuple[str, ...]] = {
    "food": ("food", "restaurant", "dining", "cafe", "cuisine", "street food"),
    "culture": ("museum", "culture", "cultural", "history", "gallery", "heritage", "temple"),
    "nature": ("nature", "park", "hike", "trail", "outdoor", "beach"),
    "nightlife": ("nightlife", "bar", "club", "pub", "live music"),
    "shopping": ("shopping", "market", "mall", "boutique"),
    "family": ("family", "kids", "child", "children"),
    "adventure": ("adventure", "climb", "surf", "kayak", "thrill", "sports"),
}

DURATION_WORDS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
}


def _build_invalid_prompt_event() -> dict[str, object]:
    event = ErrorEvent(
        timestamp=datetime.now(UTC).isoformat(),
        data=ErrorData(
            code="INVALID_PROMPT",
            message=(
                "This request can't be processed. Please provide a safe "
                "travel-planning prompt."
            ),
            details={},
        ),
    )
    return event.to_payload()


def _is_prompt_unsafe(prompt: str) -> bool:
    return any(pattern.search(prompt) for pattern in UNSAFE_PROMPT_PATTERNS)


def _extract_duration_days(prompt: str) -> int:
    digit_match = re.search(r"\b(\d{1,2})\s*(?:day|days)\b", prompt, flags=re.IGNORECASE)
    if digit_match:
        return max(1, int(digit_match.group(1)))

    word_match = re.search(
        r"\b(one|two|three|four|five|six|seven|eight|nine|ten)\s*(?:day|days)\b",
        prompt,
        flags=re.IGNORECASE,
    )
    if word_match:
        return DURATION_WORDS[word_match.group(1).lower()]

    return 1


def _extract_destination(prompt: str) -> str:
    match = re.search(
        (
            r"\b(?:in|to|visit|around)\s+"
            r"([A-Za-z][A-Za-z\s'\-]{1,60}?)"
            r"(?=\s+(?:for|with|during|this|next|and)\b|[,.!?]|$)"
        ),
        prompt,
        flags=re.IGNORECASE,
    )
    if not match:
        return "Unknown Destination"

    destination = re.sub(r"\s+", " ", match.group(1)).strip(" .,!?")
    return destination.title() if destination else "Unknown Destination"


def _extract_interest_categories(prompt: str) -> list[str]:
    lower_prompt = prompt.lower()
    categories = [
        category
        for category, keywords in INTEREST_KEYWORDS.items()
        if any(keyword in lower_prompt for keyword in keywords)
    ]

    if not categories:
        return DEFAULT_INTEREST_CATEGORIES.copy()

    return categories[:5]


def _build_research_tasks(destination: str, interests: list[str]) -> list[dict[str, str]]:
    interest_phrase = ", ".join(interests[:3])
    tasks = [
        {
            "name": "Local Research",
            "query": (
                f"Top {interest_phrase} venues in {destination} with names, addresses, "
                "ratings, opening hours, and price range"
            ),
        },
        {
            "name": "Event Checking",
            "query": (
                f"Current and upcoming events in {destination} related to {interest_phrase} "
                "with venue details"
            ),
        },
        {
            "name": "Route Optimization",
            "query": (
                f"Efficient travel routes between popular {interest_phrase} spots in {destination} "
                "for itinerary planning"
            ),
        },
    ]
    return tasks[:MAX_TASKS]


async def planner_node(state: AgentState) -> AgentState:
    """Parse prompt and create research tasks for downstream execution."""
    prompt = str(state.get("prompt", "")).strip()

    if _is_prompt_unsafe(prompt):
        return {
            **state,
            "destination": "",
            "duration_days": 1,
            "interest_categories": [],
            "tasks": [],
            "task_results": {},
            "error_event": _build_invalid_prompt_event(),
        }

    destination = _extract_destination(prompt)
    duration_days = _extract_duration_days(prompt)
    interest_categories = _extract_interest_categories(prompt)
    tasks = _build_research_tasks(destination, interest_categories)

    return {
        **state,
        "destination": destination,
        "duration_days": duration_days,
        "interest_categories": interest_categories,
        "tasks": tasks,
        "task_results": state.get("task_results", {}),
        "error_event": None,
    }
