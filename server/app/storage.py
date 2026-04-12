"""SQLite-backed persistence for the standalone bridge."""

from __future__ import annotations

from datetime import datetime
from pathlib import Path
import sqlite3

from .models import DeviceRegistrationRequest, DeviceSummary, SnapshotPayload


class Storage:
    """Small SQLite wrapper for device registrations and latest snapshots."""

    def __init__(self, database_path: Path) -> None:
        database_path.parent.mkdir(parents=True, exist_ok=True)
        self._connection = sqlite3.connect(database_path, check_same_thread=False)
        self._connection.row_factory = sqlite3.Row
        self._connection.execute("PRAGMA foreign_keys = ON")

    def initialize(self) -> None:
        """Create tables if they do not already exist."""
        with self._connection:
            self._connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS devices (
                    device_id TEXT PRIMARY KEY,
                    device_name TEXT NOT NULL,
                    profile_name TEXT NOT NULL,
                    app_id TEXT NOT NULL,
                    app_name TEXT NOT NULL,
                    app_version TEXT NOT NULL,
                    platform TEXT NOT NULL,
                    token_hash TEXT NOT NULL,
                    trmnl_webhook_url TEXT,
                    registered_at TEXT NOT NULL,
                    last_seen_at TEXT
                );

                CREATE TABLE IF NOT EXISTS snapshots (
                    device_id TEXT PRIMARY KEY REFERENCES devices(device_id) ON DELETE CASCADE,
                    captured_at TEXT NOT NULL,
                    stored_at TEXT NOT NULL,
                    payload_json TEXT NOT NULL
                );
                """
            )

    def register_device(
        self,
        payload: DeviceRegistrationRequest,
        token_hash: str,
        registered_at: datetime,
    ) -> None:
        """Insert or update one paired device."""
        with self._connection:
            self._connection.execute(
                """
                INSERT INTO devices (
                    device_id,
                    device_name,
                    profile_name,
                    app_id,
                    app_name,
                    app_version,
                    platform,
                    token_hash,
                    trmnl_webhook_url,
                    registered_at,
                    last_seen_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL)
                ON CONFLICT(device_id) DO UPDATE SET
                    device_name = excluded.device_name,
                    profile_name = excluded.profile_name,
                    app_id = excluded.app_id,
                    app_name = excluded.app_name,
                    app_version = excluded.app_version,
                    platform = excluded.platform,
                    token_hash = excluded.token_hash,
                    trmnl_webhook_url = excluded.trmnl_webhook_url,
                    registered_at = excluded.registered_at
                """,
                (
                    payload.device_id,
                    payload.device_name,
                    payload.profile_name,
                    payload.app_id,
                    payload.app_name,
                    payload.app_version,
                    payload.platform,
                    token_hash,
                    payload.trmnl_webhook_url,
                    registered_at.isoformat(),
                ),
            )

    def get_device_by_token_hash(self, token_hash: str) -> sqlite3.Row | None:
        """Look up a device by its stored token hash."""
        return self._connection.execute(
            "SELECT * FROM devices WHERE token_hash = ?",
            (token_hash,),
        ).fetchone()

    def get_device(self, device_id: str) -> sqlite3.Row | None:
        """Look up one device by identifier."""
        return self._connection.execute(
            "SELECT * FROM devices WHERE device_id = ?",
            (device_id,),
        ).fetchone()

    def save_snapshot(
        self,
        device_id: str,
        snapshot: SnapshotPayload,
        trmnl_webhook_url: str | None,
        stored_at: datetime,
    ) -> None:
        """Persist the latest snapshot and device heartbeat."""
        payload_json = snapshot.model_dump_json()
        with self._connection:
            self._connection.execute(
                """
                INSERT INTO snapshots (device_id, captured_at, stored_at, payload_json)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(device_id) DO UPDATE SET
                    captured_at = excluded.captured_at,
                    stored_at = excluded.stored_at,
                    payload_json = excluded.payload_json
                """,
                (
                    device_id,
                    snapshot.captured_at.isoformat(),
                    stored_at.isoformat(),
                    payload_json,
                ),
            )
            if trmnl_webhook_url:
                self._connection.execute(
                    """
                    UPDATE devices
                    SET trmnl_webhook_url = ?, last_seen_at = ?
                    WHERE device_id = ?
                    """,
                    (trmnl_webhook_url, stored_at.isoformat(), device_id),
                )
            else:
                self._connection.execute(
                    "UPDATE devices SET last_seen_at = ? WHERE device_id = ?",
                    (stored_at.isoformat(), device_id),
                )

    def latest_snapshot(self, device_id: str) -> tuple[SnapshotPayload, datetime] | None:
        """Return the latest stored snapshot for one device."""
        row = self._connection.execute(
            "SELECT payload_json, stored_at FROM snapshots WHERE device_id = ?",
            (device_id,),
        ).fetchone()
        if row is None:
            return None
        payload = SnapshotPayload.model_validate_json(row["payload_json"])
        stored_at = datetime.fromisoformat(row["stored_at"])
        return payload, stored_at

    def list_devices(self) -> list[DeviceSummary]:
        """Return a dashboard-friendly list of paired devices."""
        rows = self._connection.execute(
            """
            SELECT
                devices.device_id,
                devices.device_name,
                devices.profile_name,
                devices.trmnl_webhook_url,
                devices.registered_at,
                devices.last_seen_at,
                snapshots.stored_at,
                snapshots.payload_json
            FROM devices
            LEFT JOIN snapshots ON snapshots.device_id = devices.device_id
            ORDER BY devices.device_name COLLATE NOCASE
            """
        ).fetchall()

        summaries: list[DeviceSummary] = []
        for row in rows:
            latest_snapshot = None
            if row["payload_json"]:
                latest_snapshot = SnapshotPayload.model_validate_json(row["payload_json"])

            summaries.append(
                DeviceSummary(
                    device_id=row["device_id"],
                    device_name=row["device_name"],
                    profile_name=row["profile_name"],
                    registered_at=datetime.fromisoformat(row["registered_at"]),
                    last_seen_at=_parse_optional_datetime(row["last_seen_at"]),
                    last_sync_at=_parse_optional_datetime(row["stored_at"]),
                    trmnl_webhook_configured=bool(row["trmnl_webhook_url"]),
                    latest_snapshot=latest_snapshot,
                )
            )
        return summaries


def _parse_optional_datetime(value: str | None) -> datetime | None:
    """Parse an ISO timestamp if one is present."""
    if not value:
        return None
    return datetime.fromisoformat(value)
