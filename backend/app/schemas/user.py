from pydantic import BaseModel, EmailStr, Field, field_validator
from typing import Optional, List
from datetime import datetime


class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None
    dob: Optional[str] = None
    target_exam_year: Optional[int] = None
    preferred_language: Optional[str] = None


class UserCreate(UserBase):
    google_id: str


class GoogleAuthRequest(BaseModel):
    email: EmailStr
    google_id: str
    full_name: Optional[str] = None
    id_token: Optional[str] = None


class UserUpdate(BaseModel):
    full_name: str
    dob: str
    target_exam_year: Optional[int] = None
    preferred_language: Optional[str] = None


class UserResponse(UserBase):
    id: int
    google_id: Optional[str] = None
    role: str
    profile_completed: bool
    points: int
    streak_days: int
    badges: List[str] = Field(default_factory=list)
    created_at: datetime

    @field_validator("badges", mode="before")
    @classmethod
    def normalize_badges(cls, value):
        # Older rows may have null JSON values; always expose badges as a list.
        return value or []

    class Config:
        from_attributes = True


class UserRoleUpdate(BaseModel):
    role: str


class Token(BaseModel):
    access_token: str
    token_type: str


class TokenData(BaseModel):
    email: Optional[str] = None


class AuthResponse(BaseModel):
    access_token: str
    token_type: str
    user: UserResponse
