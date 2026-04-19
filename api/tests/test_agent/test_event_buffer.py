from src.agent.state import EVENT_HISTORY_LIMIT, append_event_to_buffer


def test_append_event_to_buffer_increments_cursor_and_sets_base_for_first_event() -> None:
    events: list[dict[str, object]] = []
    cursor = 0
    base = 1

    events, cursor, base = append_event_to_buffer(
        events=events,
        event_cursor=cursor,
        event_base_cursor=base,
        payload={"event_type": "thought_log"},
        limit=10,
    )

    assert cursor == 1
    assert base == 1
    assert events == [{"event_type": "thought_log"}]


def test_append_event_to_buffer_trims_oldest_and_advances_base_cursor() -> None:
    limit = 3
    events: list[dict[str, object]] = []
    cursor = 0
    base = 1

    for i in range(1, 8):
        events, cursor, base = append_event_to_buffer(
            events=events,
            event_cursor=cursor,
            event_base_cursor=base,
            payload={"event_type": "thought_log", "i": i},
            limit=limit,
        )

    # Cursor is monotonic
    assert cursor == 7
    # Buffer length is bounded
    assert len(events) == limit
    # Base cursor advances by the number of dropped events (7 appended - 3 kept = 4 dropped)
    assert base == 1 + 4
    # Kept events are the last `limit` payloads
    assert [payload["i"] for payload in events] == [5, 6, 7]


def test_event_history_limit_constant_is_positive() -> None:
    assert EVENT_HISTORY_LIMIT > 0
