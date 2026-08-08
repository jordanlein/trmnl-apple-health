"""TRMNL payload helpers for the standalone bridge."""

from __future__ import annotations

from datetime import datetime
import json
from urllib import error, request
from zoneinfo import ZoneInfo

from .models import SnapshotPayload


def build_merge_variables(
    snapshot: SnapshotPayload,
    timezone_name: str | None = None,
) -> dict[str, object]:
    """Translate one Health snapshot into the TRMNL merge payload."""
    captured_at = _ensure_timezone(snapshot.captured_at)
    localized = _localize(captured_at, timezone_name)
    return {
        "profile_name": snapshot.profile_name,
        "device_name": snapshot.device_name,
        "captured_at": _iso8601(captured_at),
        "sync_time_label": _format_time(localized),
        "date_label": _format_date(localized),
        "snapshot_status": snapshot.snapshot_status,
        "rings": {
            "move": snapshot.move_kilocalories,
            "move_goal": snapshot.move_goal_kilocalories,
            "move_percent": snapshot.move_percent,
            "exercise": snapshot.exercise_minutes,
            "exercise_goal": snapshot.exercise_goal_minutes,
            "exercise_percent": snapshot.exercise_percent,
            "stand": snapshot.stand_hours,
            "stand_goal": snapshot.stand_goal_hours,
            "stand_percent": snapshot.stand_percent,
        },
        "activity": {
            "steps": snapshot.steps,
            "distance_km": round(snapshot.distance_kilometers, 2),
            "distance_mi": round(snapshot.distance_miles, 2),
            "flights_climbed": snapshot.flights_climbed,
        },
        "health": {
            "latest_heart_rate_bpm": snapshot.latest_heart_rate_bpm,
            "sleep_hours": round(snapshot.sleep_hours, 1),
            "latest_workout": (
                {
                    "activity_type": snapshot.latest_workout.activity_type,
                    "start_date": _iso8601(snapshot.latest_workout.start_date),
                    "duration_seconds": round(snapshot.latest_workout.duration_seconds),
                    "total_energy_burned_kilocalories": round(
                        snapshot.latest_workout.total_energy_burned_kilocalories
                    ),
                }
                if snapshot.latest_workout
                else None
            ),
        },
    }


def push_to_trmnl(
    webhook_url: str,
    merge_variables: dict[str, object],
) -> tuple[bool, str | None]:
    """Push one payload update to a TRMNL webhook endpoint."""
    body = json.dumps(
        {
            "merge_variables": merge_variables,
        }
    ).encode("utf-8")
    push_request = request.Request(
        webhook_url,
        data=body,
        method="POST",
        headers={
            "Content-Type": "application/json",
            "User-Agent": "trmnl-health-standalone/0.3.0",
        },
    )

    try:
        with request.urlopen(push_request, timeout=20) as response:
            if 200 <= response.status < 300:
                return True, None
            return False, f"TRMNL returned HTTP {response.status}"
    except error.HTTPError as exc:
        return False, exc.read().decode("utf-8", errors="replace") or str(exc)
    except error.URLError as exc:
        return False, str(exc.reason)


def _ensure_timezone(value: datetime) -> datetime:
    """Treat naive timestamps as UTC to keep formatting stable."""
    if value.tzinfo is None:
        return value.replace(tzinfo=ZoneInfo("UTC"))
    return value


def _localize(value: datetime, timezone_name: str | None) -> datetime:
    """Convert timestamps into the configured local timezone."""
    if not timezone_name:
        return value.astimezone()
    return value.astimezone(ZoneInfo(timezone_name))


def _iso8601(value: datetime) -> str:
    """Render ISO8601 timestamps with Z for UTC values."""
    return value.astimezone(ZoneInfo("UTC")).isoformat().replace("+00:00", "Z")


def _format_time(value: datetime) -> str:
    """Return compact 12-hour time labels for TRMNL."""
    return value.strftime("%I:%M %p").lstrip("0")


def _format_date(value: datetime) -> str:
    """Return the same compact date label used elsewhere in the project."""
    return f"{value.strftime('%a, %b')} {value.day}"
