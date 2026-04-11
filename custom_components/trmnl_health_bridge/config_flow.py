"""Config flow for TRMNL Health Bridge."""

from __future__ import annotations

from collections.abc import Mapping
from urllib.parse import urlparse

import voluptuous as vol

from homeassistant import config_entries
from homeassistant.const import CONF_NAME
from homeassistant.core import callback
from homeassistant.data_entry_flow import FlowResult
from homeassistant.helpers import selector

from .const import (
    CONF_DEBOUNCE_SECONDS,
    CONF_SNAPSHOT_ENTITY_ID,
    CONF_SUBSCRIPTION_TIER,
    CONF_TRMNL_WEBHOOK_URL,
    DEFAULT_DEBOUNCE_SECONDS,
    DEFAULT_NAME,
    DEFAULT_SUBSCRIPTION_TIER,
    DOMAIN,
    SUBSCRIPTION_TIERS,
)


def _looks_like_http_url(value: str) -> bool:
    parsed = urlparse(value)
    return parsed.scheme in {"http", "https"} and bool(parsed.netloc)


class TRMNLHealthBridgeConfigFlow(config_entries.ConfigFlow, domain=DOMAIN):
    """Handle a config flow for TRMNL Health Bridge."""

    VERSION = 1

    @staticmethod
    @callback
    def async_get_options_flow(
        config_entry: config_entries.ConfigEntry,
    ) -> config_entries.OptionsFlow:
        return TRMNLHealthBridgeOptionsFlow(config_entry)

    async def async_step_user(
        self, user_input: Mapping[str, object] | None = None
    ) -> FlowResult:
        errors: dict[str, str] = {}

        if user_input is not None:
            webhook_url = str(user_input[CONF_TRMNL_WEBHOOK_URL]).strip()
            if not _looks_like_http_url(webhook_url):
                errors[CONF_TRMNL_WEBHOOK_URL] = "invalid_url"
            else:
                await self.async_set_unique_id(
                    f"{webhook_url}:{user_input[CONF_SNAPSHOT_ENTITY_ID]}"
                )
                self._abort_if_unique_id_configured()

                return self.async_create_entry(
                    title=str(user_input[CONF_NAME]).strip() or DEFAULT_NAME,
                    data={
                        CONF_NAME: str(user_input[CONF_NAME]).strip() or DEFAULT_NAME,
                        CONF_SNAPSHOT_ENTITY_ID: str(
                            user_input[CONF_SNAPSHOT_ENTITY_ID]
                        ).strip(),
                        CONF_TRMNL_WEBHOOK_URL: webhook_url,
                        CONF_SUBSCRIPTION_TIER: str(
                            user_input[CONF_SUBSCRIPTION_TIER]
                        ),
                        CONF_DEBOUNCE_SECONDS: int(
                            user_input[CONF_DEBOUNCE_SECONDS]
                        ),
                    },
                )

        return self.async_show_form(
            step_id="user",
            data_schema=_build_schema(user_input),
            errors=errors,
        )


class TRMNLHealthBridgeOptionsFlow(config_entries.OptionsFlow):
    """Handle options for TRMNL Health Bridge."""

    def __init__(self, config_entry: config_entries.ConfigEntry) -> None:
        self.config_entry = config_entry

    async def async_step_init(
        self, user_input: Mapping[str, object] | None = None
    ) -> FlowResult:
        errors: dict[str, str] = {}

        if user_input is not None:
            webhook_url = str(user_input[CONF_TRMNL_WEBHOOK_URL]).strip()
            if not _looks_like_http_url(webhook_url):
                errors[CONF_TRMNL_WEBHOOK_URL] = "invalid_url"
            else:
                return self.async_create_entry(
                    title="",
                    data={
                        CONF_SNAPSHOT_ENTITY_ID: str(
                            user_input[CONF_SNAPSHOT_ENTITY_ID]
                        ).strip(),
                        CONF_TRMNL_WEBHOOK_URL: webhook_url,
                        CONF_SUBSCRIPTION_TIER: str(
                            user_input[CONF_SUBSCRIPTION_TIER]
                        ),
                        CONF_DEBOUNCE_SECONDS: int(
                            user_input[CONF_DEBOUNCE_SECONDS]
                        ),
                    },
                )

        current = {**self.config_entry.data, **self.config_entry.options}
        return self.async_show_form(
            step_id="init",
            data_schema=_build_schema(current),
            errors=errors,
        )


def _build_schema(user_input: Mapping[str, object] | None) -> vol.Schema:
    """Build a shared form schema for config and options flows."""
    defaults = user_input or {}
    return vol.Schema(
        {
            vol.Required(
                CONF_NAME, default=defaults.get(CONF_NAME, DEFAULT_NAME)
            ): str,
            vol.Required(
                CONF_SNAPSHOT_ENTITY_ID,
                default=defaults.get(CONF_SNAPSHOT_ENTITY_ID, ""),
            ): selector.EntitySelector(
                selector.EntitySelectorConfig(domain="sensor")
            ),
            vol.Required(
                CONF_TRMNL_WEBHOOK_URL,
                default=defaults.get(CONF_TRMNL_WEBHOOK_URL, ""),
            ): str,
            vol.Required(
                CONF_SUBSCRIPTION_TIER,
                default=defaults.get(
                    CONF_SUBSCRIPTION_TIER, DEFAULT_SUBSCRIPTION_TIER
                ),
            ): selector.SelectSelector(
                selector.SelectSelectorConfig(
                    options=list(SUBSCRIPTION_TIERS),
                    mode=selector.SelectSelectorMode.DROPDOWN,
                )
            ),
            vol.Required(
                CONF_DEBOUNCE_SECONDS,
                default=defaults.get(
                    CONF_DEBOUNCE_SECONDS, DEFAULT_DEBOUNCE_SECONDS
                ),
            ): selector.NumberSelector(
                selector.NumberSelectorConfig(
                    min=15,
                    max=1800,
                    mode=selector.NumberSelectorMode.BOX,
                    step=15,
                )
            ),
        }
    )
