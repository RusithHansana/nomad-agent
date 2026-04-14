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
