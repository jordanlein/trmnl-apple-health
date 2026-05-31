# Setup

## Recommended: direct TRMNL sync

Use the `TRMNLHealthSync` iPhone app with the published Apple Health Recipe.
This is the easiest route and does not require Home Assistant or a server.

1. In the TRMNL web app, open `Plugins`.
2. Scroll to `Recipes`, search for the Apple Health Recipe, and install it.
3. Open the installed Recipe settings and copy its `TRMNL Health Sync Webhook URL`.
4. Install and open `TRMNLHealthSync` on your iPhone.
5. In the app, choose `TRMNL Direct`, paste the webhook URL, and tap
   `Connect TRMNL & Sync`.
6. Approve the HealthKit permissions requested by iOS.
7. Confirm the TRMNL plugin preview shows your rings and metrics.
8. Optionally add `TRMNL Health Sync -> Sync Apple Health` to a Shortcuts
   automation and turn off `Ask Before Running`.

The app reads one compact daily snapshot from Apple Health and sends it
directly to TRMNL. No second iPhone app or server is required.

## Developer fallback: Private Plugin templates

Use this only before the Recipe is publicly available or while developing
layout changes. TRMNL says creating a Private Plugin requires the Developer
add-on or a BYOD license.

1. In TRMNL, go to `Plugins -> Private Plugin -> New`.
2. Create a plugin with the `Webhook` strategy.
3. Open `Edit Markup`.
4. Paste the matching templates listed below.
5. Save the plugin so TRMNL generates its webhook URL.
6. Copy that URL into the iPhone app.

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

1. Install the Apple Health Recipe in TRMNL and copy its webhook URL.
2. In HACS, open the three-dot menu and choose `Custom repositories`.
3. Add `https://github.com/jordanlein/trmnl-apple-health` as an `Integration`.
4. Download `TRMNL Apple Health Bridge` and restart Home Assistant.
5. In your Home Assistant user profile, create a long-lived access token.
6. In the iPhone app, choose `Home Assistant`, enter the base URL and token,
   then tap `Connect Home Assistant & Sync`.
7. In Home Assistant, go to `Settings -> Devices & services -> Add integration`
   and add `TRMNL Health Bridge`.
8. Select the resulting `Health Snapshot` sensor, paste the TRMNL webhook URL,
   and save.

### Self-hosted bridge

1. Install the Apple Health Recipe in TRMNL and copy its webhook URL.
2. Clone this repository onto a server with Docker Compose.
3. Copy `docker-compose.example.yml` to `docker-compose.yml`.
4. Set a private `TRMNL_HEALTH_SETUP_TOKEN`.
5. Start the bridge with `docker compose up --build -d`.
6. Open `http://<your-server>:8421` to confirm the bridge dashboard loads.
7. In the iPhone app, choose `Self-Hosted Bridge`, then enter the bridge URL,
   setup token, and TRMNL webhook URL.
8. Tap `Connect Bridge & Sync`, then confirm data appears in the bridge
   dashboard and the TRMNL plugin preview.

See [standalone-server.md](standalone-server.md) for the bridge API and
environment variables.

## Notes

- Direct mode stores the TRMNL webhook URL in the iOS keychain.
- The app coalesces HealthKit observer updates to respect TRMNL webhook limits.
- Home Assistant and the self-hosted bridge remain supported but optional.
