import os
import subprocess
import sys
from pathlib import Path


def run_step(name: str, command: list[str], env: dict[str, str] | None = None) -> None:
    print(f"\n==> {name}")
    print("$", " ".join(command))
    result = subprocess.run(command, env=env, check=False)
    if result.returncode != 0:
        raise SystemExit(f"Step failed: {name}")


def validate_production_environment() -> None:
    environment = os.getenv("ENVIRONMENT", "development").lower()
    if environment != "production":
        print("ENVIRONMENT is not production. Skipping strict production checks.")
        return

    secret_key = os.getenv("SECRET_KEY", "")
    allowed_origins = os.getenv("ALLOWED_ORIGINS", "")
    verify_google = os.getenv("VERIFY_GOOGLE_TOKEN", "false").lower()
    google_client_id = os.getenv("GOOGLE_CLIENT_ID", "")

    issues: list[str] = []
    if len(secret_key) < 32 or secret_key == "super-secret-jwt-key!@#":
        issues.append("SECRET_KEY must be >= 32 chars and not default in production")
    if allowed_origins.strip() == "*" or not allowed_origins.strip():
        issues.append(
            "ALLOWED_ORIGINS must be an explicit comma-separated allowlist in production"
        )
    if verify_google != "true":
        issues.append("VERIFY_GOOGLE_TOKEN must be true in production")
    if not google_client_id.strip():
        issues.append("GOOGLE_CLIENT_ID must be set in production")

    if issues:
        print("Production environment validation failed:")
        for issue in issues:
            print(f"- {issue}")
        raise SystemExit(1)

    print("Production environment validation passed")


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]
    os.chdir(project_root)

    env = os.environ.copy()
    env.setdefault("DATABASE_URL", "sqlite:///./release_check.db")
    env.setdefault("PYTEST_DISABLE_PLUGIN_AUTOLOAD", "1")

    validate_production_environment()

    py = sys.executable

    run_step("Check migration heads", [py, "-m", "alembic", "heads"], env=env)
    run_step("Apply migrations", [py, "-m", "alembic", "upgrade", "head"], env=env)
    run_step("Show current migration", [py, "-m", "alembic", "current"], env=env)
    run_step("Detect pending model diffs", [py, "-m", "alembic", "check"], env=env)
    run_step("Run backend tests", [py, "-m", "pytest"], env=env)

    print("\nRelease check completed successfully")


if __name__ == "__main__":
    main()
