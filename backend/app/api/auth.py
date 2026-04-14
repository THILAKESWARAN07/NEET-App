from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from ..core.database import get_db
from ..core.security import (
    create_access_token,
    verify_password,
    get_password_hash,
    revoke_token,
)
from ..core.config import settings
from ..models.user import User
from ..schemas.user import GoogleAuthRequest, AuthResponse, UserResponse, UserUpdate
from .deps import get_current_user, get_bearer_token
from pydantic import BaseModel


# Request models
class RegisterRequest(BaseModel):
    email: str
    password: str
    name: str


class LoginRequest(BaseModel):
    email: str
    password: str


try:
    from google.oauth2 import id_token
    from google.auth.transport import requests as google_requests
except Exception:
    id_token = None
    google_requests = None

router = APIRouter()


# Email/Password Registration
@router.post("/register", response_model=AuthResponse)
def register(user_in: RegisterRequest, db: Session = Depends(get_db)):
    """Register a new user with email and password"""
    # Check if user exists
    existing_user = db.query(User).filter(User.email == user_in.email).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Email already registered")

    # Create new user
    user = User(
        email=user_in.email,
        hashed_password=get_password_hash(user_in.password),
        full_name=user_in.name,
        profile_completed=False,
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": user}


# Email/Password Login
@router.post("/login", response_model=AuthResponse)
def login(user_in: LoginRequest, db: Session = Depends(get_db)):
    """Login with email and password"""
    user = db.query(User).filter(User.email == user_in.email).first()
    if not user or not verify_password(user_in.password, user.hashed_password or ""):
        raise HTTPException(status_code=401, detail="Invalid email or password")

    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": user}


@router.post("/google", response_model=AuthResponse)
def google_auth(user_in: GoogleAuthRequest, db: Session = Depends(get_db)):
    if settings.VERIFY_GOOGLE_TOKEN:
        if not user_in.id_token:
            raise HTTPException(status_code=400, detail="id_token is required")
        if not id_token or not google_requests:
            raise HTTPException(
                status_code=500, detail="Google auth libraries are not installed"
            )
        try:
            payload = id_token.verify_oauth2_token(
                user_in.id_token,
                google_requests.Request(),
                settings.GOOGLE_CLIENT_ID,
            )
            if payload.get("email") != user_in.email:
                raise HTTPException(
                    status_code=400, detail="Email mismatch in google token"
                )
        except ValueError as exc:
            raise HTTPException(status_code=401, detail=f"Invalid Google token: {exc}")

    user = db.query(User).filter(User.email == user_in.email).first()
    if not user:
        user = User(
            email=user_in.email,
            google_id=user_in.google_id,
            full_name=user_in.full_name,
            profile_completed=False,
        )
        db.add(user)
    else:
        user.google_id = user_in.google_id
        if user_in.full_name and not user.full_name:
            user.full_name = user_in.full_name

    db.commit()
    db.refresh(user)

    access_token = create_access_token(data={"sub": user.email})
    return {"access_token": access_token, "token_type": "bearer", "user": user}


@router.get("/me", response_model=UserResponse)
def read_users_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/profile/complete", response_model=UserResponse)
def update_profile(
    profile_data: UserUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    current_user.full_name = profile_data.full_name
    current_user.dob = profile_data.dob
    current_user.target_exam_year = profile_data.target_exam_year
    current_user.preferred_language = profile_data.preferred_language
    current_user.profile_completed = True

    db.commit()
    db.refresh(current_user)
    return current_user


@router.post("/logout")
def logout(token: str = Depends(get_bearer_token)):
    revoke_token(token)
    return {"message": "Logged out successfully"}
