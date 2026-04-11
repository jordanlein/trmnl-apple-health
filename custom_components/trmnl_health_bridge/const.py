"""Constants for the TRMNL Health Bridge integration."""

from __future__ import annotations

DOMAIN = "trmnl_health_bridge"

CONF_DEBOUNCE_SECONDS = "debounce_seconds"
CONF_SNAPSHOT_ENTITY_ID = "snapshot_entity_id"
CONF_SUBSCRIPTION_TIER = "subscription_tier"
CONF_TRMNL_WEBHOOK_URL = "trmnl_webhook_url"

DEFAULT_DEBOUNCE_SECONDS = 45
DEFAULT_NAME = "TRMNL Apple Health"
DEFAULT_SUBSCRIPTION_TIER = "standard"

SERVICE_SYNC_NOW = "sync_now"

SUBSCRIPTION_TIERS: dict[str, int] = {
    "standard": 300,
    "plus": 120,
}
