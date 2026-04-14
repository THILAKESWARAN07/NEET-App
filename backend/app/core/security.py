from datetime import datetime, timedelta
from typing import Optional
from uuid import uuid4
from jose import jwt, JWTError
from passlib.context import CryptContext
from .config import settings

# Password hashing - use argon2 instead of bcrypt to avoid version issues
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
_revoked_tokens: dict[str, datetime] = {}


def _cleanup_revoked_tokens() -> None:
    now = datetime.utcnow()
    expired = [token for token, until in _revoked_tokens.items() if until <= now]
    for token in expired:
        _revoked_tokens.pop(token, None)


def revoke_token(token: str) -> None:
    _cleanup_revoked_tokens()
    _revoked_tokens[token] = datetime.utcnow() + timedelta(
        minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
    )


def is_token_revoked(token: str) -> bool:
    _cleanup_revoked_tokens()
    return token in _revoked_tokens


def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    if not hashed_password:
        return False
    return pwd_context.verify(plain_password, hashed_password)


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(
            minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES
        )
    to_encode.update({"exp": expire, "iat": datetime.utcnow(), "jti": str(uuid4())})
    encoded_jwt = jwt.encode(
        to_encode, settings.SECRET_KEY, algorithm=settings.ALGORITHM
    )
    return encoded_jwt


def verify_token(token: str) -> Optional[dict]:
    if is_token_revoked(token):
        return None
    try:
        payload = jwt.decode(
            token, settings.SECRET_KEY, algorithms=[settings.ALGORITHM]
        )
        return payload
    except JWTError:
        return None
