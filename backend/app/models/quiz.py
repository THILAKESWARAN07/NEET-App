from sqlalchemy import Column, Integer, String, Float, ForeignKey, JSON, Text
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy import DateTime
from ..core.database import Base


class Question(Base):
    __tablename__ = "questions"

    id = Column(Integer, primary_key=True, index=True)
    subject = Column(String, index=True)  # Physics, Chemistry, Botany, Zoology
    topic = Column(String, index=True)
    difficulty = Column(String)  # Easy, Medium, Hard
    question_text = Column(Text, nullable=False)
    options = Column(JSON, nullable=False)  # Store options as a list of strings
    correct_answer = Column(String, nullable=False)
    explanation = Column(Text, nullable=True)
    image_url = Column(String, nullable=True)

    answers = relationship("Answer", back_populates="question")
    attempt_questions = relationship("QuizAttemptQuestion", back_populates="question")
    bookmarks = relationship("Bookmark", back_populates="question")


class QuizAttempt(Base):
    __tablename__ = "quiz_attempts"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"))
    start_time = Column(DateTime(timezone=True), default=func.now())
    end_time = Column(DateTime(timezone=True), nullable=True)
    time_taken = Column(Integer, default=0)  # in seconds
    duration_seconds = Column(Integer, default=10800)  # 3 hours by default
    score = Column(Float, default=0)
    status = Column(
        String, default="in_progress"
    )  # in_progress, completed, timeout, terminated
    cheat_count = Column(Integer, default=0)
    cheat_logs = Column(JSON, default=list)
    test_type = Column(String, default="full")  # full, subject
    subject = Column(String, nullable=True)

    user = relationship("User", back_populates="quiz_attempts")
    answers = relationship("Answer", back_populates="attempt")
    assigned_questions = relationship("QuizAttemptQuestion", back_populates="attempt")


class QuizAttemptQuestion(Base):
    __tablename__ = "quiz_attempt_questions"

    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("quiz_attempts.id"), index=True)
    question_id = Column(Integer, ForeignKey("questions.id"), index=True)

    attempt = relationship("QuizAttempt", back_populates="assigned_questions")
    question = relationship("Question", back_populates="attempt_questions")


class Answer(Base):
    __tablename__ = "answers"

    id = Column(Integer, primary_key=True, index=True)
    attempt_id = Column(Integer, ForeignKey("quiz_attempts.id"))
    question_id = Column(Integer, ForeignKey("questions.id"))
    selected_option = Column(String, nullable=True)

    attempt = relationship("QuizAttempt", back_populates="answers")
    question = relationship("Question", back_populates="answers")


class StudyMaterial(Base):
    __tablename__ = "study_materials"

    id = Column(Integer, primary_key=True, index=True)
    subject = Column(String, index=True, nullable=False)
    title = Column(String, nullable=False)
    pdf_url = Column(String, nullable=False)
    uploaded_at = Column(DateTime(timezone=True), server_default=func.now())


class Bookmark(Base):
    __tablename__ = "bookmarks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    question_id = Column(Integer, ForeignKey("questions.id"), index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    user = relationship("User", back_populates="bookmarks")
    question = relationship("Question", back_populates="bookmarks")


class Announcement(Base):
    __tablename__ = "announcements"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())


class ScheduledTest(Base):
    __tablename__ = "scheduled_tests"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    test_type = Column(String, default="full")
    subject = Column(String, nullable=True)
    scheduled_at = Column(DateTime(timezone=True), nullable=False)
    duration_seconds = Column(Integer, default=10800)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
