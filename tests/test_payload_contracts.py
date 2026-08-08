"""Contract tests for the optional Home Assistant and standalone bridges."""

from __future__ import annotations

from datetime import UTC, datetime
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

from server.app.models import (
    DeviceRegistrationRequest,
    LatestWorkoutPayload,
    SnapshotPayload,
    SnapshotUpdateRequest,
)
from server.app.storage import Storage
from server.app.trmnl import build_merge_variables


def _load_home_assistant_payload_module():
    """Load the pure helper without requiring a Home Assistant installation."""
    path = (
        Path(__file__).parents[1]
        / "custom_components"
        / "trmnl_health_bridge"
        / "payload.py"
    )
    spec = importlib.util.spec_from_file_location("trmnl_health_payload", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load the Home Assistant payload helper")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


HA_PAYLOAD = _load_home_assistant_payload_module()


def _snapshot(status: str = "fresh") -> SnapshotPayload:
    return SnapshotPayload(
        captured_at=datetime(2026, 8, 8, 5, 17, tzinfo=UTC),
        device_name="Test iPhone",
        profile_name="Apple Health",
        steps=7314,
        distance_kilometers=5.82,
        distance_miles=3.62,
        flights_climbed=8,
        move_kilocalories=428,
        move_goal_kilocalories=500,
        move_percent=86,
        exercise_minutes=24,
        exercise_goal_minutes=30,
        exercise_percent=80,
        stand_hours=9,
        stand_goal_hours=12,
        stand_percent=75,
        latest_heart_rate_bpm=72,
        sleep_hours=7.4,
        latest_workout=LatestWorkoutPayload(
            activity_type="Running",
            start_date=datetime(2026, 8, 8, 3, 15, tzinfo=UTC),
            duration_seconds=1920,
            total_energy_burned_kilocalories=286,
        ),
        snapshot_status=status,
    )


class StandalonePayloadTests(unittest.TestCase):
    def test_cached_status_reaches_compact_trmnl_payload(self) -> None:
        payload = build_merge_variables(_snapshot("cached"), "America/Chicago")

        self.assertEqual(payload["snapshot_status"], "cached")
        self.assertEqual(payload["date_label"], "Sat, Aug 8")
        self.assertEqual(
            payload["health"]["latest_workout"][
                "total_energy_burned_kilocalories"
            ],
            286,
        )
        body = json.dumps({"merge_variables": payload}).encode("utf-8")
        self.assertLess(len(body), 2_048)

    def test_older_clients_default_to_fresh(self) -> None:
        request = SnapshotUpdateRequest(snapshot=_snapshot())
        self.assertIsNone(request.snapshot_status)
        self.assertEqual(request.normalized_snapshot().snapshot_status, "fresh")

    def test_envelope_status_overrides_or_preserves_nested_status(self) -> None:
        cached_envelope = SnapshotUpdateRequest(
            snapshot=_snapshot("fresh"), snapshot_status="cached"
        )
        cached_snapshot = SnapshotUpdateRequest(snapshot=_snapshot("cached"))

        self.assertEqual(cached_envelope.normalized_snapshot().snapshot_status, "cached")
        self.assertEqual(cached_snapshot.normalized_snapshot().snapshot_status, "cached")

    def test_storage_round_trip_preserves_source_status(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            storage = Storage(Path(directory) / "bridge.db")
            storage.initialize()
            storage.register_device(
                payload=DeviceRegistrationRequest(
                    setup_token="unused-in-storage",
                    device_id="test-device",
                    device_name="Test iPhone",
                    app_id="example.test",
                    app_name="TRMNL Health Sync",
                    app_version="1.0",
                    profile_name="Apple Health",
                ),
                token_hash="not-a-real-token",
                registered_at=datetime.now(tz=UTC),
            )
            storage.save_snapshot(
                device_id="test-device",
                snapshot=_snapshot("cached"),
                trmnl_webhook_url=None,
                stored_at=datetime.now(tz=UTC),
            )

            saved = storage.latest_snapshot("test-device")
            self.assertIsNotNone(saved)
            assert saved is not None
            self.assertEqual(saved[0].snapshot_status, "cached")


class HomeAssistantPayloadTests(unittest.TestCase):
    def test_cached_status_and_legacy_workout_key_are_normalized(self) -> None:
        payload = HA_PAYLOAD.build_payload(
            state="2026-08-08T05:17:00Z",
            attrs={
                "captured_at": "2026-08-08T05:17:00Z",
                "snapshot_status": "cached",
                "latest_workout": {
                    "activity_type": "Walking",
                    "start_date": "2026-08-08T03:15:00Z",
                    "duration_seconds": 1500.4,
                    "total_energy_burned_kcal": 182.2,
                },
            },
            default_name="Apple Health",
            format_local_time=lambda _: "12:17 AM",
        )

        self.assertEqual(payload["snapshot_status"], "cached")
        self.assertEqual(payload["sync_time_label"], "12:17 AM")
        self.assertEqual(
            payload["health"]["latest_workout"],
            {
                "activity_type": "Walking",
                "start_date": "2026-08-08T03:15:00Z",
                "duration_seconds": 1500,
                "total_energy_burned_kilocalories": 182,
            },
        )

    def test_unknown_or_missing_status_defaults_to_fresh(self) -> None:
        for value in (None, "", "unexpected"):
            payload = HA_PAYLOAD.build_payload(
                state="2026-08-08T05:17:00Z",
                attrs={"snapshot_status": value},
                default_name="Apple Health",
                format_local_time=lambda _: "12:17 AM",
            )
            self.assertEqual(payload["snapshot_status"], "fresh")


if __name__ == "__main__":
    unittest.main()
