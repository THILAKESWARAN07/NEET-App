import os
from pathlib import Path


TEST_DB_PATH = Path(__file__).resolve().parent / "test_suite.db"
TEST_DATABASE_URL = f"sqlite:///{TEST_DB_PATH.as_posix()}"


os.environ.setdefault("ENVIRONMENT", "development")
os.environ["DATABASE_URL"] = TEST_DATABASE_URL
