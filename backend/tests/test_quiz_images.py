from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401
from app.core.database import Base, get_db
from app.core.security import get_password_hash
from app.main import app

TEST_DB_PATH = Path(__file__).resolve().parent / "test_quiz_images.db"
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


def test_quiz_start_includes_question_image_url() -> None:
    db = TestingSessionLocal()
    try:
        user = models.User(
            email="quiz_image_user@neet.com",
            hashed_password=get_password_hash("QuizImage123!"),
            full_name="Quiz Image User",
            profile_completed=True,
        )
        db.add(user)
        db.add(
            models.Question(
                subject="Physics",
                topic="Optics",
                difficulty="medium",
                question_text="Identify the lens shown in the image.",
                options=["Convex", "Concave", "Plano-convex", "Cylindrical"],
                correct_answer="Convex",
                explanation="The image shows a converging lens.",
                image_url="https://example.com/question-image.jpg",
            )
        )
        db.commit()
    finally:
        db.close()

    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": "quiz_image_user@neet.com", "password": "QuizImage123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        quiz_resp = client.post(
            "/api/quiz/start",
            headers={"Authorization": f"Bearer {token}"},
            json={"test_type": "full", "question_count": 1},
        )
        assert quiz_resp.status_code == 200
        payload = quiz_resp.json()
        assert payload["questions"][0]["image_url"] == "https://example.com/question-image.jpg"