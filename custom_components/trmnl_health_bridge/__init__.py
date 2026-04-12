"""Home Assistant setup for TRMNL Health Bridge."""

from __future__ import annotations

from collections.abc import Awaitable, Callable

import voluptuous as vol

from homeassistant.config_entries import ConfigEntry
from homeassistant.core import HomeAssistant, ServiceCall

from .const import DOMAIN, SERVICE_SYNC_NOW
from .manager import TRMNLHealthBridgeManager

ATTR_ENTRY_ID = "entry_id"
ManagerMap = dict[str, TRMNLHealthBridgeManager]

SERVICE_SCHEMA = vol.Schema(
    {
        vol.Optional(ATTR_ENTRY_ID): str,
    }
)


async def async_setup(hass: HomeAssistant, config: dict) -> bool:
    """Set up the integration domain."""
    hass.data.setdefault(DOMAIN, {})
    return True


async def async_setup_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Set up one config entry."""
    manager = TRMNLHealthBridgeManager(hass, entry)
    managers: ManagerMap = hass.data.setdefault(DOMAIN, {})
    managers[entry.entry_id] = manager
    await manager.async_start()

    if not hass.services.async_has_service(DOMAIN, SERVICE_SYNC_NOW):
        hass.services.async_register(
            DOMAIN,
            SERVICE_SYNC_NOW,
            _async_handle_sync_now_factory(hass),
            schema=SERVICE_SCHEMA,
        )

    entry.async_on_unload(entry.add_update_listener(async_reload_entry))
    return True


async def async_unload_entry(hass: HomeAssistant, entry: ConfigEntry) -> bool:
    """Unload one config entry."""
    managers: ManagerMap = hass.data[DOMAIN]
    manager = managers.pop(entry.entry_id)
    await manager.async_stop()

    if not managers and hass.services.async_has_service(DOMAIN, SERVICE_SYNC_NOW):
        hass.services.async_remove(DOMAIN, SERVICE_SYNC_NOW)

    return True


async def async_reload_entry(hass: HomeAssistant, entry: ConfigEntry) -> None:
    """Reload when options change."""
    await hass.config_entries.async_reload(entry.entry_id)


def _async_handle_sync_now_factory(
    hass: HomeAssistant,
) -> Callable[[ServiceCall], Awaitable[None]]:
    async def _async_handle_sync_now(call: ServiceCall) -> None:
        managers: ManagerMap = hass.data[DOMAIN]
        entry_id = call.data.get(ATTR_ENTRY_ID)

        if entry_id:
            manager = managers.get(entry_id)
            if manager is not None:
                await manager.async_push_now("manual")
            return

        for manager in managers.values():
            await manager.async_push_now("manual")

    return _async_handle_sync_now
