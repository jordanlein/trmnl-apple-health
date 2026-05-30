# Setup

## Recommended: direct TRMNL sync

Use the `TRMNLHealthSync` iPhone app with one webhook-strategy Private Plugin.

1. In TRMNL, go to `Plugins -> Private Plugin -> New`.
2. Create a plugin with the `Webhook` strategy.
3. Open `Edit Markup` and paste the four matching templates from `trmnl/`.
4. Save the plugin so TRMNL generates its webhook URL.
5. Build and install `TRMNLHealthSync`.
6. In the app, choose `TRMNL Direct`, paste the webhook URL, and tap
   `Connect TRMNL & Sync`.
7. Approve the HealthKit permissions requested by iOS.
8. Optionally add `TRMNL Health Sync -> Sync Apple Health` to a Shortcuts
   automation and turn off `Ask Before Running`.

The app reads one compact daily snapshot from Apple Health and sends it
directly to TRMNL. No second iPhone app or server is required.

## Private Plugin templates

Use:

- `trmnl/apple-health-dashboard.liquid` for `full`
- `trmnl/apple-health-dashboard.half_horizontal.liquid` for `half_horizontal`
- `trmnl/apple-health-dashboard.half_vertical.liquid` for `half_vertical`
- `trmnl/apple-health-dashboard.quadrant.liquid` for `quadrant`
- `trmnl/apple-health-dashboard.fields.yaml` for recipe custom fields

The bundled serverless transform is only a compact normalizer for marketplace
packaging. A private webhook plugin can leave its serverless language set to
`None`.

## Optional bridge paths

Use a bridge only when you intentionally want another system in the middle:

- `Home Assistant`
- `Self-Hosted Bridge`

### Home Assistant

1. Install `TRMNL Health Bridge` through HACS.
2. Restart Home Assistant.
3. Add the integration from `Settings -> Devices & Services`.
4. In the iPhone app, choose `Home Assistant`, enter the base URL and
   long-lived token, and connect.
5. Select the resulting `Health Snapshot` sensor in the integration.

### Self-hosted bridge

1. Copy `docker-compose.example.yml` to `docker-compose.yml`.
2. Set a private `TRMNL_HEALTH_SETUP_TOKEN`.
3. Start the bridge with `docker compose up --build -d`.
4. In the iPhone app, choose `Self-Hosted Bridge`, then enter the bridge URL,
   setup token, and TRMNL webhook URL.

See [standalone-server.md](standalone-server.md) for the bridge API and
environment variables.

## Notes

- Direct mode stores the TRMNL webhook URL in the iOS keychain.
- The app coalesces HealthKit observer updates to respect TRMNL webhook limits.
- Home Assistant and the self-hosted bridge remain supported but optional.
