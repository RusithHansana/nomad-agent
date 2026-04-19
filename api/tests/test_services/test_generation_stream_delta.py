from src.services.generation_stream import _compute_event_delta


def test_compute_event_delta_empty_buffer() -> None:
    delta, last = _compute_event_delta(events=[], base_cursor=1, last_sent_cursor=0)
    assert delta == []
    assert last == 0


def test_compute_event_delta_returns_only_new_events() -> None:
    events = [{"n": 1}, {"n": 2}, {"n": 3}]
    base_cursor = 1

    delta, last = _compute_event_delta(events=events, base_cursor=base_cursor, last_sent_cursor=0)
    assert [e["n"] for e in delta] == [1, 2, 3]
    assert last == 3

    delta, last = _compute_event_delta(events=events, base_cursor=base_cursor, last_sent_cursor=2)
    assert [e["n"] for e in delta] == [3]
    assert last == 3


def test_compute_event_delta_handles_gap_due_to_trim() -> None:
    # Simulate a trimmed buffer where the oldest retained event has cursor 5.
    events = [{"n": 5}, {"n": 6}, {"n": 7}]
    base_cursor = 5

    delta, last = _compute_event_delta(events=events, base_cursor=base_cursor, last_sent_cursor=2)
    assert [e["n"] for e in delta] == [5, 6, 7]
    assert last == 7
