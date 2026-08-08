"""Pure payload normalization shared by the Home Assistant runtime and tests."""

from __future__ import annotations

from collections.abc import Callable


def build_payload(
    state: object,
    attrs: dict[str, object],
    default_name: str,
    format_local_time: Callable[[object], str],
) -> dict[str, object]:
    """Normalize Home Assistant sensor attributes into the TRMNL contract."""
    captured_at = attrs.get("captured_at", state)
    return {
        "profile_name": attrs.get("profile_name", default_name),
        "device_name": attrs.get("device_name", default_name),
        "captured_at": captured_at,
        "sync_time_label": format_local_time(captured_at),
        "date_label": attrs.get("date_label", "Today"),
        "snapshot_status": snapshot_status(attrs.get("snapshot_status")),
        "rings": {
            "move": round_number(attrs.get("move_kcal")),
            "move_goal": round_number(attrs.get("move_goal_kcal")),
            "move_percent": round_number(attrs.get("move_percent")),
            "exercise": round_number(attrs.get("exercise_minutes")),
            "exercise_goal": round_number(attrs.get("exercise_goal_minutes")),
            "exercise_percent": round_number(attrs.get("exercise_percent")),
            "stand": round_number(attrs.get("stand_hours")),
            "stand_goal": round_number(attrs.get("stand_goal_hours")),
            "stand_percent": round_number(attrs.get("stand_percent")),
        },
        "activity": {
            "steps": round_number(attrs.get("steps")),
            "distance_km": round_number(attrs.get("distance_km"), 2),
            "distance_mi": round_number(attrs.get("distance_mi"), 2),
            "flights_climbed": round_number(attrs.get("flights_climbed")),
        },
        "health": {
            "latest_heart_rate_bpm": round_number(
                attrs.get("latest_heart_rate_bpm")
            ),
            "sleep_hours": round_number(attrs.get("sleep_hours"), 1),
            "latest_workout": normalize_workout(attrs.get("latest_workout")),
        },
    }


def round_number(value: object, digits: int = 0) -> int | float:
    """Convert Home Assistant state attributes into sane numeric output."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0 if digits == 0 else 0.0
    if digits == 0:
        return int(round(number))
    return round(number, digits)


def snapshot_status(value: object) -> str:
    """Return the canonical source status, defaulting older sensors to fresh."""
    return "cached" if str(value).lower() == "cached" else "fresh"


def normalize_workout(value: object) -> dict[str, object] | None:
    """Normalize app sensor workout attributes to the TRMNL contract."""
    if not isinstance(value, dict):
        return None

    activity_type = value.get("activity_type")
    start_date = value.get("start_date")
    if not activity_type or not start_date:
        return None

    return {
        "activity_type": activity_type,
        "start_date": start_date,
        "duration_seconds": round_number(value.get("duration_seconds")),
        "total_energy_burned_kilocalories": round_number(
            value.get(
                "total_energy_burned_kilocalories",
                value.get("total_energy_burned_kcal"),
            )
        ),
    }
