"""Runtime manager for TRMNL Health Bridge."""

from __future__ import annotations

import asyncio
import hashlib
import json
import logging
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime

from aiohttp import ClientError

from homeassistant.config_entries import ConfigEntry
from homeassistant.const import CONF_NAME
from homeassistant.core import CALLBACK_TYPE, Event, HomeAssistant, callback
from homeassistant.helpers.aiohttp_client import async_get_clientsession
from homeassistant.helpers.event import async_call_later, async_track_state_change_event
from homeassistant.helpers.typing import StateType
from homeassistant.util import dt as dt_util

from .const import (
    CONF_DEBOUNCE_SECONDS,
    CONF_SNAPSHOT_ENTITY_ID,
    CONF_SUBSCRIPTION_TIER,
    CONF_TRMNL_WEBHOOK_URL,
    DOMAIN,
    SUBSCRIPTION_TIERS,
)

_LOGGER = logging.getLogger(__name__)


@dataclass(slots=True)
class PushContext:
    """Static config used during a push."""

    entry_id: str
    name: str
    snapshot_entity_id: str
    subscription_tier: str
    webhook_url: str
    debounce_seconds: int

    @property
    def minimum_push_seconds(self) -> int:
        return SUBSCRIPTION_TIERS.get(self.subscription_tier, SUBSCRIPTION_TIERS["standard"])


class TRMNLHealthBridgeManager:
    """Manage one config entry."""

    def __init__(self, hass: HomeAssistant, entry: ConfigEntry) -> None:
        self.hass = hass
        self.entry = entry
        self.context = PushContext(
            entry_id=entry.entry_id,
            name=str(entry.title or entry.data.get(CONF_NAME, "TRMNL Apple Health")),
            snapshot_entity_id=str(
                entry.options.get(CONF_SNAPSHOT_ENTITY_ID, entry.data[CONF_SNAPSHOT_ENTITY_ID])
            ),
            subscription_tier=str(
                entry.options.get(CONF_SUBSCRIPTION_TIER, entry.data[CONF_SUBSCRIPTION_TIER])
            ),
            webhook_url=str(
                entry.options.get(CONF_TRMNL_WEBHOOK_URL, entry.data[CONF_TRMNL_WEBHOOK_URL])
            ),
            debounce_seconds=int(
                entry.options.get(CONF_DEBOUNCE_SECONDS, entry.data[CONF_DEBOUNCE_SECONDS])
            ),
        )
        self._session = async_get_clientsession(hass)
        self._unsub_state: CALLBACK_TYPE | None = None
        self._unsub_debounce: CALLBACK_TYPE | None = None
        self._push_lock = asyncio.Lock()
        self._last_push_at: datetime | None = None
        self._last_payload_hash: str | None = None
        self._pending_reason: str | None = None

    async def async_start(self) -> None:
        """Start listening for state changes."""
        self._unsub_state = async_track_state_change_event(
            self.hass,
            [self.context.snapshot_entity_id],
            self._handle_snapshot_event,
        )
        await self.async_request_push("startup", immediate=True)

    async def async_stop(self) -> None:
        """Clean up runtime listeners."""
        if self._unsub_state is not None:
            self._unsub_state()
            self._unsub_state = None
        if self._unsub_debounce is not None:
            self._unsub_debounce()
            self._unsub_debounce = None

    async def async_request_push(self, reason: str, immediate: bool = False) -> None:
        """Schedule a push respecting rate limits."""
        if self._unsub_debounce is not None:
            self._unsub_debounce()
            self._unsub_debounce = None

        self._pending_reason = reason
        delay = 0 if immediate else self._calculate_delay_seconds()
        _LOGGER.debug(
            "Scheduling TRMNL push for %s in %ss because %s",
            self.context.entry_id,
            delay,
            reason,
        )
        self._unsub_debounce = async_call_later(
            self.hass,
            delay,
            self._handle_debounced_push,
        )

    async def async_push_now(self, reason: str = "manual") -> bool:
        """Push the latest snapshot to TRMNL."""
        async with self._push_lock:
            state = self.hass.states.get(self.context.snapshot_entity_id)
            if state is None:
                _LOGGER.warning(
                    "Snapshot entity %s was not found for %s",
                    self.context.snapshot_entity_id,
                    self.context.entry_id,
                )
                if reason != "manual":
                    self.hass.async_create_task(
                        self.async_request_push("snapshot_unavailable_retry")
                    )
                return False

            payload = self._build_payload(state.state, dict(state.attributes))
            payload_hash = hashlib.sha256(
                json.dumps(payload, sort_keys=True).encode("utf-8")
            ).hexdigest()
            if payload_hash == self._last_payload_hash and reason != "manual":
                _LOGGER.debug(
                    "Skipping unchanged payload for %s", self.context.entry_id
                )
                return True

            body = {
                "merge_strategy": "deep_merge",
                "merge_variables": payload,
            }

            try:
                async with self._session.post(
                    self.context.webhook_url,
                    json=body,
                    headers={
                        "Content-Type": "application/json",
                        "User-Agent": "home-assistant-trmnl-health-bridge/0.1.5",
                    },
                    timeout=20,
                ) as response:
                    if response.status >= 400:
                        response_text = await response.text()
                        _LOGGER.error(
                            "TRMNL webhook push failed for %s with %s: %s",
                            self.context.entry_id,
                            response.status,
                            response_text,
                        )
                        return False
            except (TimeoutError, ClientError) as err:
                _LOGGER.error(
                    "TRMNL webhook push failed for %s: %s",
                    self.context.entry_id,
                    err,
                )
                return False

            self._last_payload_hash = payload_hash
            self._last_push_at = datetime.now(tz=UTC)
            _LOGGER.info(
                "Pushed Apple Health snapshot from %s to TRMNL (%s)",
                self.context.snapshot_entity_id,
                reason,
            )
            return True

    @callback
    def _handle_snapshot_event(self, event: Event) -> None:
        """React to Home Assistant state changes."""
        self.hass.async_create_task(self.async_request_push("snapshot_changed"))

    @callback
    def _handle_debounced_push(self, _: datetime) -> None:
        """Execute a previously scheduled push on the event loop."""
        self._unsub_debounce = None
        reason = self._pending_reason or "scheduled"
        self._pending_reason = None
        self.hass.async_create_task(self.async_push_now(reason))

    def _calculate_delay_seconds(self) -> int:
        """Compute the next allowable push window."""
        if self._last_push_at is None:
            return max(self.context.debounce_seconds, 1)

        elapsed = (datetime.now(tz=UTC) - self._last_push_at).total_seconds()
        remaining = max(self.context.minimum_push_seconds - int(elapsed), 0)
        return max(self.context.debounce_seconds, remaining)

    def _build_payload(
        self,
        state: StateType,
        attrs: dict[str, object],
    ) -> dict[str, object]:
        """Normalize the sensor attributes into a compact TRMNL payload."""
        captured_at = attrs.get("captured_at", state)
        return {
            "profile_name": attrs.get("profile_name", self.context.name),
            "device_name": attrs.get("device_name", self.context.name),
            "captured_at": captured_at,
            "sync_time_label": _format_local_time(captured_at),
            "date_label": attrs.get("date_label", "Today"),
            "rings": {
                "move": _round_number(attrs.get("move_kcal")),
                "move_goal": _round_number(attrs.get("move_goal_kcal")),
                "move_percent": _round_number(attrs.get("move_percent")),
                "exercise": _round_number(attrs.get("exercise_minutes")),
                "exercise_goal": _round_number(attrs.get("exercise_goal_minutes")),
                "exercise_percent": _round_number(attrs.get("exercise_percent")),
                "stand": _round_number(attrs.get("stand_hours")),
                "stand_goal": _round_number(attrs.get("stand_goal_hours")),
                "stand_percent": _round_number(attrs.get("stand_percent")),
            },
            "activity": {
                "steps": _round_number(attrs.get("steps")),
                "distance_km": _round_number(attrs.get("distance_km"), 2),
                "distance_mi": _round_number(attrs.get("distance_mi"), 2),
                "flights_climbed": _round_number(attrs.get("flights_climbed")),
            },
            "health": {
                "latest_heart_rate_bpm": _round_number(attrs.get("latest_heart_rate_bpm")),
                "sleep_hours": _round_number(attrs.get("sleep_hours"), 1),
                "latest_workout": attrs.get("latest_workout"),
            },
        }


def _round_number(value: object, digits: int = 0) -> int | float:
    """Convert Home Assistant state attributes into sane numeric output."""
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0 if digits == 0 else 0.0
    if digits == 0:
        return int(round(number))
    return round(number, digits)


def _format_local_time(value: object) -> str:
    """Convert an ISO-ish timestamp into Home Assistant local time."""
    if not value:
        return ""

    parsed = dt_util.parse_datetime(str(value))
    if parsed is None:
        return ""

    return dt_util.as_local(parsed).strftime("%-I:%M %p")
