from sqlalchemy import Boolean, Column, Date, DateTime, Integer, JSON, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..core.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    google_id = Column(
        String, unique=True, index=True, nullable=True
    )  # Nullable for email/password users
    hashed_password = Column(String, nullable=True)  # Nullable for Google OAuth users
    full_name = Column(String)
    dob = Column(String, nullable=True)  # Could be Date type depending on need
    role = Column(String, default="user")  # 'user' or 'admin'
    profile_completed = Column(Boolean, default=False)
    target_exam_year = Column(Integer, nullable=True)
    preferred_language = Column(String, nullable=True)
    points = Column(Integer, default=0)
    streak_days = Column(Integer, default=0)
    last_activity_date = Column(Date, nullable=True)
    badges = Column(JSON, default=list)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

    quiz_attempts = relationship("QuizAttempt", back_populates="user")
    bookmarks = relationship("Bookmark", back_populates="user")
    ai_chat_messages = relationship("AIChatMessage", back_populates="user")
