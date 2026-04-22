from pathlib import Path

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401
from app.core.database import Base, get_db
from app.core.security import get_password_hash
from app.main import app

TEST_DB_PATH = Path(__file__).resolve().parent / "test_quiz_order.db"
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


def test_quiz_start_returns_questions_in_order_from_first_question() -> None:
    db = TestingSessionLocal()
    try:
        user = models.User(
            email="quiz_order_user@neet.com",
            hashed_password=get_password_hash("QuizOrder123!"),
            full_name="Quiz Order User",
            profile_completed=True,
        )
        db.add(user)

        for index in range(1, 11):
            db.add(
                models.Question(
                    subject="Physics",
                    topic=f"Topic {index}",
                    difficulty="medium",
                    question_text=f"Question {index}?",
                    options=["A", "B", "C", "D"],
                    correct_answer="A",
                    explanation="Because A",
                )
            )

        db.commit()
    finally:
        db.close()

    with TestClient(app) as client:
        login_resp = client.post(
            "/api/auth/login",
            json={"email": "quiz_order_user@neet.com", "password": "QuizOrder123!"},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        start_resp = client.post(
            "/api/quiz/start",
            headers={"Authorization": f"Bearer {token}"},
            json={"test_type": "full", "question_count": 10},
        )
        assert start_resp.status_code == 200
        start_payload = start_resp.json()
        start_ids = [question["id"] for question in start_payload["questions"]]

        assert len(start_ids) == 10
        assert start_ids == sorted(start_ids)
        assert start_ids[0] == min(start_ids)

        active_resp = client.get(
            "/api/quiz/active",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert active_resp.status_code == 200
        active_payload = active_resp.json()
        active_ids = [question["id"] for question in active_payload["questions"]]

        assert active_ids == start_ids
