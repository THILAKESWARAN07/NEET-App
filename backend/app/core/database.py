from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base
from sqlalchemy.orm import sessionmaker
from .config import settings

def _connect_args_for(url: str) -> dict:
    return {"check_same_thread": False} if "sqlite" in url else {}


engine = create_engine(settings.DATABASE_URL, connect_args=_connect_args_for(settings.DATABASE_URL))
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


def set_engine(database_url: str):
    global engine
    engine = create_engine(database_url, connect_args=_connect_args_for(database_url))
    SessionLocal.configure(bind=engine)
    return engine


# Dependency
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
