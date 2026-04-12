"""Configuration helpers for the standalone bridge."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
import os


@dataclass(slots=True)
class Settings:
    """Runtime settings loaded from environment variables."""

    server_name: str
    database_path: Path
    setup_token: str
    default_trmnl_webhook_url: str | None
    timezone_name: str | None


def load_settings() -> Settings:
    """Read environment variables into a frozen settings object."""
    data_dir = Path(os.getenv("TRMNL_HEALTH_DATA_DIR", "/data"))
    database_path = Path(
        os.getenv("TRMNL_HEALTH_DB_PATH", str(data_dir / "trmnl_health.db"))
    )
    return Settings(
        server_name=os.getenv("TRMNL_HEALTH_SERVER_NAME", "TRMNL Health Bridge"),
        database_path=database_path,
        setup_token=os.getenv("TRMNL_HEALTH_SETUP_TOKEN", "change-me"),
        default_trmnl_webhook_url=os.getenv("TRMNL_HEALTH_DEFAULT_TRMNL_WEBHOOK_URL"),
        timezone_name=os.getenv("TZ"),
    )
