# NEET Prep App - Production Baseline

This repository now includes a production-ready baseline for a NEET preparation platform with:

- Flutter mobile app (Android and iOS)
- FastAPI backend
- PostgreSQL-ready SQLAlchemy models
- Google OAuth login + JWT
- Timed quiz system with anti-cheat logs and auto-submit
- Resume attempt flow and server-side timeout enforcement
- AI tutor endpoints (chat, PDF summarization, concept explain)
- Materials, bookmarks, analytics, and admin APIs

## 1) Backend Setup (FastAPI)

### Prerequisites

- Python 3.11+
- PostgreSQL 14+

### Install

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Environment

Create `backend/.env`:

```env
ENVIRONMENT=development
PROJECT_NAME=NEET Prep App
DATABASE_URL=postgresql+psycopg2://postgres:postgres@localhost:5432/neet_app
SECRET_KEY=replace-with-strong-secret
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=10080
VERIFY_GOOGLE_TOKEN=false
GOOGLE_CLIENT_ID=
OPENAI_API_KEY=
OPENAI_MODEL=gpt-4o-mini
ALLOWED_ORIGINS=http://localhost:3000,http://localhost:8000,http://127.0.0.1:8000
```

Quick start:

```powershell
cd backend
Copy-Item .env.example .env -Force
```

Then put your real value in `OPENAI_API_KEY` inside `.env`.

Production template is available at `backend/.env.production.example`.

For production, startup validation now enforces all of the following:

- `ENVIRONMENT=production`
- `SECRET_KEY` length >= 32 and not default
- `ALLOWED_ORIGINS` cannot be `*`
- `VERIFY_GOOGLE_TOKEN=true`
- `GOOGLE_CLIENT_ID` must be set

### Run API

```powershell
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Health and readiness probes

- `GET /health` returns process-level liveness.
- `GET /ready` returns readiness and validates DB connectivity (`SELECT 1`).

### Backend smoke test

In another terminal:

```powershell
python test_api.py
```

Optional override:

```powershell
$env:API_BASE_URL="http://localhost:8001"
python test_api.py
```

### Database migrations (Alembic)

Run schema migrations before starting the API:

```powershell
cd backend
alembic upgrade head
```

Create a new migration after model changes:

```powershell
cd backend
alembic revision --autogenerate -m "describe change"
alembic upgrade head
```

### Core API Routes

- `POST /api/auth/google`
- `POST /api/auth/logout`
- `GET /api/auth/me`
- `POST /api/auth/profile/complete`
- `POST /api/quiz/start`
- `GET /api/quiz/active`
- `POST /api/quiz/{attempt_id}/answer`
- `POST /api/quiz/{attempt_id}/log-cheat`
- `POST /api/quiz/{attempt_id}/submit`
- `GET /api/quiz/{attempt_id}/result`
- `GET /api/quiz/analytics/dashboard`
- `GET /api/quiz/leaderboard`
- `GET /api/quiz/gamification/me`
- `GET /api/quiz/study-plan`
- `GET /api/quiz/rank-prediction`
- `GET /api/quiz/wrong-questions`
- `POST /api/quiz/start-reattempt`
- `POST /api/quiz/bookmarks`
- `GET /api/quiz/bookmarks`
- `GET /api/quiz/bookmarks/details`
- `DELETE /api/quiz/bookmarks/{bookmark_id}`
- `GET /api/quiz/scheduled-tests`
- `GET /api/materials/`
- `POST /api/materials/` (admin)
- `DELETE /api/materials/{material_id}` (admin)
- `POST /api/ai/chat`
- `POST /api/ai/summarize-pdf`
- `POST /api/ai/explain`
- `GET /api/ai/status`
- `GET /api/ai/history`
- `DELETE /api/ai/history`
- `GET /api/admin/users`
- `PUT /api/admin/users/{user_id}/role`
- `PUT /api/admin/questions/{question_id}`
- `DELETE /api/admin/questions/{question_id}`
- `POST /api/admin/questions/bulk-csv`
- `GET /api/admin/cheat-dashboard`
- `POST /api/admin/announcements`
- `GET /api/admin/announcements`
- `DELETE /api/admin/announcements/{announcement_id}`
- `GET /api/admin/announcements/public`
- `POST /api/admin/schedule-tests`
- `GET /api/admin/schedule-tests`
- `PUT /api/admin/schedule-tests/{test_id}`
- `DELETE /api/admin/schedule-tests/{test_id}`

Reattempt options:

- Wrong-question pool (default behavior)
- Latest completed test pool by sending `from_latest_completed_test=true` in `POST /api/quiz/start-reattempt`

Quiz UI support in mobile app includes:

- Mark-for-review per question
- Question navigator grid (jump to any question)

## 2) Mobile Setup (Flutter)

### Install

```powershell
cd mobile_app
flutter pub get
```

### Run

```powershell
flutter run
```

For Android emulator backend access, default API URL is already set to `http://10.0.2.2:8000/api`.

If you need a different URL:

```powershell
flutter run --dart-define=API_BASE_URL=http://<your-host>:8000/api
```

## 3) Implemented Mobile Screens

- Splash/Auth gate
- Google login
- First-time profile setup
- Dashboard with all requested modules
- Quiz screen with timer, anti-cheat warnings, and auto-submit
- Result screen
- Wrong-question review and reattempt flow
- Analytics dashboard
- Daily study plan
- Scheduled tests (upcoming/live)
- Leaderboard and rank prediction
- Announcement feed
- Study materials list
- AI chat + PDF upload summarize
- Bookmarks and revision
- Admin panel (role-driven visibility)

## 4) Anti-Cheat Details

### Mobile

- Lifecycle monitoring detects background/minimize events.
- 1st and 2nd violations show warnings.
- 3rd violation triggers auto-submit.
- Android secure flag is enabled in `MainActivity`.
- Fullscreen immersive mode is enforced during quiz.

### Backend

- Cheat logs are stored in `quiz_attempts.cheat_logs`.
- `cheat_count` increments per violation.
- Attempt auto-terminates at violation >= 3.
- Timeout is validated server-side on every critical attempt action.

## 5) Database Tables

Implemented SQLAlchemy models:

- `users`
- `questions`
- `quiz_attempts`
- `quiz_attempt_questions`
- `answers`
- `study_materials`
- `bookmarks`
- `announcements`
- `scheduled_tests`

## 6) Production Hardening Checklist

- Keep using Alembic migrations as the only schema change mechanism
- Enable strict CORS allowlist
- Enable `VERIFY_GOOGLE_TOKEN=true` and set `GOOGLE_CLIENT_ID`
- Add Redis + Celery/Arq workers for scheduled jobs
- Add device fingerprinting for multi-device session control
- Encrypt sensitive logs and enforce audit retention
- Configure cloud object storage (S3/GCS) for PDF uploads
- Add observability (Sentry, OpenTelemetry, structured logging)

## 7) Optional Next Milestones

- Rank prediction model endpoint
- Personalized study plan generator
- Spaced-repetition scheduler based on wrong-question history
- Voice assistant in AI screen
- Offline quiz caching and sync

## 8) CI

GitHub Actions CI is configured at `.github/workflows/ci.yml` and runs:

- Quality gates: pre-commit + ruff lint + ruff format check
- Backend dependency install + Alembic migration + pytest
- Flutter dependency install + flutter analyze

## 9) Docker Deployment (Backend + Postgres)

From the repository root:

```powershell
Copy-Item backend/.env.example backend/.env -Force
docker compose up --build
```

This starts:

- `db` (PostgreSQL)
- `backend` (FastAPI on `http://localhost:8000`)

Backend container startup runs `alembic upgrade head` before launching the API.

Compose also exposes health checks:

- DB: `pg_isready`
- Backend readiness: `/ready`

## 10) Release Checklist Automation

Run automated release checks:

```powershell
cd backend
python scripts/release_check.py
```

The script validates and runs:

- Production env safety checks (when `ENVIRONMENT=production`)
- Alembic heads/current and migration apply
- Alembic drift detection (`alembic check`)
- Backend pytest suite

## 11) Windows One-Command Bootstrap

From repository root:

```powershell
./scripts/bootstrap_windows.ps1
```

Optional modes:

```powershell
./scripts/bootstrap_windows.ps1 -RunSmokeTest
./scripts/bootstrap_windows.ps1 -RunServer
```

## 12) Staged Deployment Workflow

A staged deploy workflow is available at `.github/workflows/deploy.yml`.

- Auto target mapping: `develop -> development`, `staging -> staging`, `main -> production`
- Manual trigger with environment selection via GitHub Actions UI
- Runs release checks before image build
- Builds and deploys backend image to Google Cloud Run

Current deploy workflow uses Google Cloud Run and expects these GitHub secrets:

- `GCP_WORKLOAD_IDENTITY_PROVIDER`
- `GCP_SERVICE_ACCOUNT`
- `GCP_PROJECT_ID`
- `GCP_REGION`
- `GCP_ARTIFACT_REPO`
- `CLOUD_RUN_SERVICE`
- `SECRET_KEY`
- `DATABASE_URL`
- `ALLOWED_ORIGINS`
- `VERIFY_GOOGLE_TOKEN`
- `GOOGLE_CLIENT_ID`
- `OPENAI_API_KEY`
- `OPENAI_MODEL`

Deployment behavior:

- Build image with current commit SHA tag
- Deploy to Cloud Run with runtime env vars from secrets
- Run post-deploy checks against `/health` and `/ready`

## 13) Go-Live Execution Checklist

For final production launch, follow the step-by-step runbook in `GO_LIVE_CHECKLIST.md`.
