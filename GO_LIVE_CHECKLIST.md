# NEET App Go-Live Checklist

This checklist is designed to be executed in order for a production deployment.

## 1) Pre-Deployment Readiness

- [ ] Confirm latest branch has passing CI (`quality`, `backend`, `flutter`).
- [ ] Confirm latest migrations are committed in `backend/alembic/versions/`.
- [ ] Confirm no pending model drift:

```powershell
cd backend
python scripts/release_check.py
```

Expected:
- `alembic heads` shows a single head.
- `alembic check` reports no new upgrade operations.
- pytest passes.

## 2) Production Environment Values

Use `backend/.env.production.example` as baseline and ensure values are production-grade:

- [ ] `ENVIRONMENT=production`
- [ ] `DATABASE_URL` points to managed Postgres (SSL enabled if required by provider)
- [ ] `SECRET_KEY` is strong (>= 32 chars, random)
- [ ] `ALLOWED_ORIGINS` lists only real frontend/admin domains
- [ ] `VERIFY_GOOGLE_TOKEN=true`
- [ ] `GOOGLE_CLIENT_ID` set
- [ ] `OPENAI_API_KEY` set (if AI enabled)
- [ ] `OPENAI_MODEL` set

## 3) GitHub Secrets (Required)

Configure all of the following repository/environment secrets before running deploy workflow:

- [ ] `GCP_WORKLOAD_IDENTITY_PROVIDER`
- [ ] `GCP_SERVICE_ACCOUNT`
- [ ] `GCP_PROJECT_ID`
- [ ] `GCP_REGION`
- [ ] `GCP_ARTIFACT_REPO`
- [ ] `CLOUD_RUN_SERVICE`
- [ ] `DATABASE_URL`
- [ ] `SECRET_KEY`
- [ ] `ALLOWED_ORIGINS`
- [ ] `VERIFY_GOOGLE_TOKEN`
- [ ] `GOOGLE_CLIENT_ID`
- [ ] `OPENAI_API_KEY`
- [ ] `OPENAI_MODEL`

## 4) Deploy Execution

### Option A: Manual deploy run (recommended first)

- [ ] Open GitHub Actions -> `Deploy` workflow
- [ ] Click `Run workflow`
- [ ] Select target (`development`, `staging`, `production`)
- [ ] Start run and monitor all jobs

### Option B: Branch-driven deploy

- `develop` -> development
- `staging` -> staging
- `main` -> production

## 5) Automated Checks During Deploy

The pipeline should complete these automatically:

- [ ] Release checks pass (`backend/scripts/release_check.py`)
- [ ] Image builds and pushes successfully
- [ ] Cloud Run service updates successfully
- [ ] Post-deploy checks pass:
  - [ ] `GET /health`
  - [ ] `GET /ready`

## 6) Post-Deploy Smoke Validation

Run these against deployed base URL:

- [ ] `GET /health` returns 200
- [ ] `GET /ready` returns 200
- [ ] Auth login flow works
- [ ] Profile completion works
- [ ] Quiz start/submit/result works
- [ ] AI status endpoint works

For local API script checks:

```powershell
$env:API_BASE_URL="https://<your-deployed-host>"
python test_api.py
```

## 7) Security Validation

- [ ] Confirm CORS is restricted to trusted origins only
- [ ] Confirm JWT secret is not default and not leaked
- [ ] Confirm Google token verification is enabled in production
- [ ] Confirm admin role endpoints are inaccessible to non-admin users

## 8) Monitoring & Incident Readiness

- [ ] Enable service logs retention and alerting
- [ ] Add uptime monitor on `/health`
- [ ] Add readiness monitor on `/ready`
- [ ] Record rollback procedure (previous image tag + redeploy command)

## 9) Rollback Plan

If deployment fails after rollout:

- [ ] Redeploy previous known-good image tag
- [ ] Verify `/health` and `/ready`
- [ ] Re-run key smoke checks
- [ ] Announce incident and resolution window

## 10) Launch Sign-Off

- [ ] Engineering sign-off
- [ ] Product sign-off
- [ ] Admin operations sign-off
- [ ] Go-live announcement approved

---

## Quick Commands Reference

```powershell
# Backend release checks
cd backend
python scripts/release_check.py

# Flutter static check
cd ../mobile_app
flutter analyze

# Local smoke against deployed host
cd ..
$env:API_BASE_URL="https://<your-deployed-host>"
python test_api.py
```
