"""Pydantic models for the standalone bridge API."""

from __future__ import annotations

from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict


class DeviceRegistrationRequest(BaseModel):
    """Pair one app install with the local bridge."""

    setup_token: str
    device_id: str
    device_name: str
    app_id: str
    app_name: str
    app_version: str
    platform: str = "ios"
    profile_name: str = "Apple Health"
    trmnl_webhook_url: str | None = None


class DeviceRegistration(BaseModel):
    """Stored pairing metadata returned to the app."""

    device_id: str
    device_name: str
    profile_name: str
    trmnl_webhook_configured: bool
    registered_at: datetime


class DeviceRegistrationResponse(DeviceRegistration):
    """Pairing response with the generated device token."""

    device_token: str
    default_trmnl_webhook_configured: bool


class LatestWorkoutPayload(BaseModel):
    """Compact latest-workout summary sent from the iPhone app."""

    activity_type: str
    start_date: datetime
    duration_seconds: float
    total_energy_burned_kilocalories: float


class SnapshotPayload(BaseModel):
    """Daily Apple Health snapshot sent from the iPhone app."""

    model_config = ConfigDict(extra="ignore")

    captured_at: datetime
    device_name: str
    profile_name: str
    steps: int
    distance_kilometers: float
    distance_miles: float
    flights_climbed: int
    move_kilocalories: int
    move_goal_kilocalories: int
    move_percent: int
    exercise_minutes: int
    exercise_goal_minutes: int
    exercise_percent: int
    stand_hours: int
    stand_goal_hours: int
    stand_percent: int
    latest_heart_rate_bpm: int = 0
    sleep_hours: float = 0
    latest_workout: LatestWorkoutPayload | None = None
    snapshot_status: Literal["fresh", "cached"] = "fresh"


class SnapshotUpdateRequest(BaseModel):
    """Payload wrapper for sync requests."""

    snapshot: SnapshotPayload
    snapshot_status: Literal["fresh", "cached"] | None = None
    trmnl_webhook_url: str | None = None

    def normalized_snapshot(self) -> SnapshotPayload:
        """Apply an envelope source status while accepting older request shapes."""
        return self.snapshot.model_copy(
            update={
                "snapshot_status": self.snapshot_status or self.snapshot.snapshot_status
            }
        )


class SnapshotUpdateResponse(BaseModel):
    """Server response after accepting a snapshot."""

    device_id: str
    stored_at: datetime
    pushed_to_trmnl: bool
    trmnl_webhook_configured: bool
    trmnl_push_error: str | None = None


class DeviceSummary(BaseModel):
    """Compact status view for the bridge dashboard."""

    model_config = ConfigDict(extra="ignore")

    device_id: str
    device_name: str
    profile_name: str
    registered_at: datetime
    last_seen_at: datetime | None = None
    last_sync_at: datetime | None = None
    trmnl_webhook_configured: bool
    latest_snapshot: SnapshotPayload | None = None
