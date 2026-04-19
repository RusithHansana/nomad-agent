# NomadAgent

AI-powered travel research agent — describe your trip in plain language, watch it research in real time, and receive a verified itinerary.

## Project Structure

- `app/` — Flutter mobile app (iOS + Android)
- `api/` — Python FastAPI backend with LangGraph agent pipeline
- `docs/` — Project documentation

## Getting Started

### Backend

```bash
cd api
python -m venv .venv
source .venv/bin/activate
uv pip install -r requirements.txt -r requirements-dev.txt

# If `uv` is not installed, use:
# pip install -r requirements.txt -r requirements-dev.txt
uvicorn src.main:app --reload --port 8000
```

Verify: `curl http://localhost:8000/api/v1/health` → `{"status": "ok"}`

### Frontend

```bash
cd app
flutter pub get
flutter run
```

## Environment Variables

Copy `.env.example` files in both `app/` and `api/` directories and fill in your keys.
See `api/.env.example` and `app/.env.example` for required variables.

## Streaming: bounded event history + cursor deltas

NomadAgent streams real-time progress updates from the backend to the app using Server-Sent Events (SSE).
To keep streaming fast and memory-bounded during long generations, the backend uses a **bounded event buffer**
with a **monotonic cursor**.

### State fields

The agent state includes:

- `events`: a rolling window (bounded list) of event payloads.
- `event_cursor`: a monotonic integer that increments once per appended event.
- `event_base_cursor`: the cursor value of `events[0]` (advances when the buffer trims old entries).

`EVENT_HISTORY_LIMIT` in `api/src/agent/state.py` controls the maximum number of events retained.

### Why this exists

The earlier approach (“append to `events` forever and stream by list length”) works for MVP load, but can:

- grow memory unbounded,
- increase per-update processing cost over time,
- break delta logic once old events are trimmed.

Cursor + base-cursor keeps the buffer bounded while still preserving a stable notion of “event order.”

### Example (trim-safe deltas)

Assume `EVENT_HISTORY_LIMIT = 3` and the backend has emitted 4 events total.

- Total emitted cursor: `event_cursor = 4`
- Oldest retained: `event_base_cursor = 2`
- Retained payloads: `events == [#2, #3, #4]`

If the streamer last sent cursor `2`, it can compute the correct list slice using:

`start_index = (last_sent_cursor + 1) - event_base_cursor`

and safely emit only `[#3, #4]`. If a client falls behind and `last_sent_cursor < event_base_cursor - 1`,
the streamer emits the current buffer window (best-effort catch-up).
