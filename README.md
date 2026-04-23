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
# To access localhost 8000
adb reverse tcp:8000 tcp:8000
flutter pub get
flutter run --dart-define-from-file=.env
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

## Pipeline Evolution

The itinerary extraction pipeline went through **5 iterative test runs** across 3 days, with each run exposing issues that were diagnosed from debug dumps and fixed before the next. This section documents the progression.

### The Initial Problem (Epic 4 Smoke Test)

After completing the Interactive Map View (Epic 4), the first on-device smoke test with real API data revealed that **every feature built in Epics 2–4 was effectively broken**:

- 🗺️ **Map was empty** — all venues had `(0, 0)` coordinates, filtered out by the defensive coordinate guard
- ⚠️ **Every venue showed "Unverified"** — the strict verification formula required opening hours, which Tavily never returns
- 📝 **Venue names were page titles** — e.g., *"THE 5 BEST Tokyo Food & Drink Festivals (2026) - Tripadvisor"*
- 📍 **Addresses contained raw HTML** — the compiler fell back to `raw_content` when no structured address existed

**Root cause**: The compiler assumed structured venue input, but Tavily returns raw web search results. The missing link was an **LLM extraction step** to parse structured venue data from raw search content.

### Fix 1: LLM Extraction Node (Test Runs 1–2)

Added a `gemini-2.5-flash-lite` extraction node between the researcher and compiler:

**Pipeline**: `planner → researcher → **extractor** → compiler`

| Metric | Before (Broken) | After Fix 1 |
|---|---|---|
| Venue count | Raw page titles | 8 → 15 venues |
| Coordinates | 0% | 0% ❌ (model limitation) |
| Addresses | Raw HTML | 25% → 33% |
| Source URLs | Random assignment | ✅ Accurate |

**Diagnosed from dumps**: Content truncation (`MAX_RAW_CONTENT_CHARS = 800`) was cutting off venue data before the LLM saw it. Increased to `6000`. Source URL attribution was index-based (round-robin), not semantic — switched to LLM-extracted `source_url`.

### Fix 2: Model Upgrade + Relevance Scoring (Test Runs 3–4)

Test Run 3 (Mirissa, Sri Lanka) exposed a **critical search failure** — Tavily returned New Jersey parks instead of Sri Lankan beaches. Test Run 4 upgraded to `gemini-3-flash-preview` but hit output truncation (only 2 venues from 25+ in sources).

**Fixes applied**:
- **Hybrid relevance scoring** — combines Tavily confidence (50%) with destination keyword matching (50%); results below 0.4 are filtered
- **Model upgrade** to `gemini-3-flash-preview` — resolved the coordinate extraction gap (0% → 100%)
- **Tiered verification** — type-specific weight tables so nature venues aren't penalized for lacking opening hours
- **Venue deduplication** — merge duplicates across search tasks, preferring richer data
- **Raw content noise reduction** — regex stripping of Markdown images, link targets, emojis, and navigation patterns

### Fix 3: Parallel Extraction + Noise Reduction (Test Run 5)

Profiling showed the extractor was the main bottleneck (~45–60s of ~90s total), running 3 independent LLM calls sequentially.

**Fixes applied**:
- **`asyncio.gather`** for concurrent LLM extraction across all venue tasks
- **Aggressive content cleaning** to reduce prompt token pressure
- **Graceful 503 handling** — failed tasks are skipped without blocking others

### Final Results (Test Run 5 vs Initial Smoke Test)

| Metric | Initial (Broken) | Final (Test 5) | Improvement |
|---|---|---|---|
| **Venues extracted** | 0 usable | **16** | ∞ |
| **Coordinates** | 0% | **100%** | Map fully populated |
| **Addresses** | Raw HTML | **100%** clean | 4× |
| **Opening hours** | 0% | **25%** | First non-zero |
| **Source URLs** | Random | **100%** accurate | Fully resolved |
| **Extraction time** | ~50s | **19.4s** | ~60% faster |
| **Verification** | 0% (all unverified) | Tiered scoring | Type-aware |
| **Error handling** | Crash on failure | Graceful degradation | 503-safe |

The full analysis with per-run breakdowns is in [`docs/pipeline_analysis.md`](docs/pipeline_analysis.md).
