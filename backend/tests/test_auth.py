from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401
from app.core.config import settings
from app.core.security import get_password_hash
from app.core.database import Base, get_db
from app.main import app

TEST_DB_PATH = Path(__file__).resolve().parent / "test_auth.db"
SQLALCHEMY_DATABASE_URL = f"sqlite:///{TEST_DB_PATH.as_posix()}"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False}
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()


def setup_module() -> None:
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()
    Base.metadata.create_all(bind=engine)
    app.dependency_overrides[get_db] = override_get_db


def teardown_module() -> None:
    app.dependency_overrides.clear()
    Base.metadata.drop_all(bind=engine)
    engine.dispose()
    if TEST_DB_PATH.exists():
        TEST_DB_PATH.unlink()


def test_register_login_me_flow() -> None:
    with TestClient(app) as client:
        register_resp = client.post(
            "/api/auth/register",
            json={
                "email": "pytest_user@neet.com",
                "password": "Pytest123!",
                "name": "Pytest User",
            },
        )
        assert register_resp.status_code == 200
        register_data = register_resp.json()
        assert register_data["user"]["email"] == "pytest_user@neet.com"

        login_resp = client.post(
            "/api/auth/login",
            json={"email": "pytest_user@neet.com", "password": "Pytest123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        me_resp = client.get(
            "/api/auth/me", headers={"Authorization": f"Bearer {token}"}
        )
        assert me_resp.status_code == 200
        me_data = me_resp.json()
        assert me_data["email"] == "pytest_user@neet.com"


def test_profile_complete_persists_new_fields() -> None:
    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": "pytest_user@neet.com", "password": "Pytest123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        complete_resp = client.post(
            "/api/auth/profile/complete",
            headers={"Authorization": f"Bearer {token}"},
            json={
                "full_name": "Pytest User",
                "dob": "2006-05-12",
                "target_exam_year": 2027,
                "preferred_language": "English",
            },
        )
        assert complete_resp.status_code == 200
        complete_data = complete_resp.json()
        assert complete_data["profile_completed"] is True
        assert complete_data["target_exam_year"] == 2027
        assert complete_data["preferred_language"] == "English"


def test_google_auth_creates_or_updates_user() -> None:
    with TestClient(app) as client:
        google_resp = client.post(
            "/api/auth/google",
            json={
                "email": "google_user@neet.com",
                "google_id": "google-oauth-id-1",
                "full_name": "Google User",
            },
        )
        assert google_resp.status_code == 200
        user = google_resp.json()["user"]
        assert user["email"] == "google_user@neet.com"
        assert user["google_id"] == "google-oauth-id-1"


def test_logout_revokes_token() -> None:
    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": "pytest_user@neet.com", "password": "Pytest123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        logout_resp = client.post(
            "/api/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert logout_resp.status_code == 200

        me_resp = client.get(
            "/api/auth/me", headers={"Authorization": f"Bearer {token}"}
        )
        assert me_resp.status_code == 401


def test_admin_email_is_promoted_on_login() -> None:
    admin_email = "admin_user@neet.com"
    original_admin_email = settings.ADMIN_EMAIL
    settings.ADMIN_EMAIL = admin_email

    db = TestingSessionLocal()
    try:
        user = models.User(
            email=admin_email,
            hashed_password=get_password_hash("AdminPass123!"),
            full_name="Admin User",
            role="user",
            profile_completed=True,
        )
        db.add(user)
        db.commit()
    finally:
        db.close()

    try:
        with TestClient(app) as client:
            login_resp = client.post(
                "/api/auth/login",
                json={"email": admin_email, "password": "AdminPass123!"},
            )
            assert login_resp.status_code == 200
            payload = login_resp.json()
            assert payload["user"]["role"] == "admin"

        db = TestingSessionLocal()
        try:
            user = db.query(models.User).filter(models.User.email == admin_email).first()
            assert user is not None
            assert user.role == "admin"
        finally:
            db.close()
    finally:
        settings.ADMIN_EMAIL = original_admin_email


def test_login_syncs_stale_profile_completed_flag() -> None:
    email = "stale_profile_user@neet.com"

    db = TestingSessionLocal()
    try:
        user = models.User(
            email=email,
            hashed_password=get_password_hash("StalePass123!"),
            full_name="Stale User",
            dob="2006-08-21",
            profile_completed=False,
        )
        db.add(user)
        db.commit()
    finally:
        db.close()

    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": email, "password": "StalePass123!"},
        )
        assert login_resp.status_code == 200
        payload = login_resp.json()
        assert payload["user"]["profile_completed"] is True


def test_gamification_profile_and_streak_update() -> None:
    db = TestingSessionLocal()
    try:
        question = models.Question(
            subject="Physics",
            topic="Kinematics",
            difficulty="Easy",
            question_text="Speed unit?",
            options=["m/s", "kg", "N", "J"],
            correct_answer="m/s",
            explanation="Speed is distance/time",
        )
        db.add(question)
        db.commit()
    finally:
        db.close()

    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": "pytest_user@neet.com", "password": "Pytest123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        start_resp = client.post(
            "/api/quiz/start",
            headers={"Authorization": f"Bearer {token}"},
            json={"test_type": "subject", "subject": "Physics", "question_count": 1},
        )
        assert start_resp.status_code == 200
        attempt_id = start_resp.json()["id"]

        submit_resp = client.post(
            f"/api/quiz/{attempt_id}/submit",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert submit_resp.status_code == 200

        gamification_resp = client.get(
            "/api/quiz/gamification/me",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert gamification_resp.status_code == 200
        payload = gamification_resp.json()
        assert payload["streak_days"] >= 1
        assert isinstance(payload["badges"], list)
