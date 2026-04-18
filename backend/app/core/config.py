from pydantic import model_validator
from pydantic_settings import BaseSettings
from pydantic_settings import SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="allow")

    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "NEET Prep App"
    DATABASE_URL: str = "sqlite:///./neet_app.db"
    SECRET_KEY: str = "super-secret-jwt-key!@#"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 7  # 7 days
    VERIFY_GOOGLE_TOKEN: bool = False
    GOOGLE_CLIENT_ID: str = ""
    ADMIN_EMAIL: str = ""
    OPENAI_API_KEY: str = ""
    OPENAI_MODEL: str = "gpt-4o-mini"
    STORAGE_BASE_URL: str = "https://storage.example.com"
    STORAGE_PROVIDER: str = ""
    STORAGE_BUCKET_NAME: str = ""
    STORAGE_REGION: str = "us-east-1"
    STORAGE_ENDPOINT_URL: str = ""
    STORAGE_OBJECT_PREFIX: str = "neet-app"
    ALLOWED_ORIGINS: str = "*"

    @property
    def allowed_origins_list(self) -> list[str]:
        origins = [
            item.strip() for item in self.ALLOWED_ORIGINS.split(",") if item.strip()
        ]
        return origins or ["*"]

    @model_validator(mode="after")
    def validate_production_settings(self):
        if self.ENVIRONMENT.lower() != "production":
            return self

        if self.SECRET_KEY == "super-secret-jwt-key!@#" or len(self.SECRET_KEY) < 32:
            raise ValueError(
                "In production, SECRET_KEY must be a strong value with length >= 32"
            )

        if self.ALLOWED_ORIGINS.strip() == "*":
            raise ValueError("In production, ALLOWED_ORIGINS cannot be '*'")

        if not self.VERIFY_GOOGLE_TOKEN:
            raise ValueError("In production, VERIFY_GOOGLE_TOKEN must be true")

        if not self.GOOGLE_CLIENT_ID.strip():
            raise ValueError("In production, GOOGLE_CLIENT_ID must be set")

        return self

settings = Settings()
