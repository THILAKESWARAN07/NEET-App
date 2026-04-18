from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi import HTTPException
from sqlalchemy import text
from sqlalchemy.exc import OperationalError
from fastapi.middleware.cors import CORSMiddleware
from .core.config import settings
from .core.database import Base, engine, set_engine
from .api import admin, ai, auth, materials, quiz

app = FastAPI(
    title=settings.PROJECT_NAME,
    version="1.0.0",
    description="FastAPI Backend for NEET Preparation App",
)

active_engine = engine


@asynccontextmanager
async def lifespan(_app: FastAPI):
    global active_engine
    try:
        Base.metadata.create_all(bind=active_engine)
    except OperationalError as exc:
        error_message = str(exc).lower()
        can_fallback = (
            settings.ENVIRONMENT.lower() != "production"
            and "postgres" in settings.DATABASE_URL
            and "does not exist" in error_message
        )
        if not can_fallback:
            raise

        sqlite_path = Path("neet_app.db").resolve().as_posix()
        sqlite_url = f"sqlite:///{sqlite_path}"
        active_engine = set_engine(sqlite_url)
        Base.metadata.create_all(bind=active_engine)
    yield


app.router.lifespan_context = lifespan

# CORS configuration
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://localhost:\d+",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(quiz.router, prefix="/api/quiz", tags=["quiz"])
app.include_router(ai.router, prefix="/api/ai", tags=["ai"])
app.include_router(materials.router, prefix="/api/materials", tags=["materials"])
app.include_router(admin.router, prefix="/api/admin", tags=["admin"])


@app.get("/")
def read_root():
    return {"message": "Welcome to NEET App Backend API"}


@app.get("/health")
def health_check():
    return {"status": "ok", "service": "backend"}


@app.get("/ready")
def readiness_check():
    try:
        with active_engine.connect() as connection:
            connection.execute(text("SELECT 1"))
        return {"status": "ready", "database": "ok"}
    except Exception as exc:  # pragma: no cover - only triggers on infra failure
        raise HTTPException(
            status_code=503,
            detail={
                "status": "not_ready",
                "database": "error",
                "detail": str(exc),
            },
        )
