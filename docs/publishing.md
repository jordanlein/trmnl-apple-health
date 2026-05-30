# Publishing Roadmap

## Product story

The publishable setup is intentionally small:

1. Install `TRMNLHealthSync`.
2. Create or install a webhook-strategy Private Plugin.
3. Connect the webhook once in the iPhone app.
4. Optionally schedule `Sync Apple Health` from Shortcuts.

The app sends one compact HealthKit snapshot directly to TRMNL. Home Assistant
and the standalone bridge remain optional paths.

## TRMNL recipe publisher bundle

- `trmnl/apple-health-dashboard.fields.yaml`
- `trmnl/apple-health-dashboard.liquid`
- `trmnl/apple-health-dashboard.half_horizontal.liquid`
- `trmnl/apple-health-dashboard.half_vertical.liquid`
- `trmnl/apple-health-dashboard.quadrant.liquid`
- `trmnl/apple-health-dashboard.transform.js`

The four layouts are designed for e-ink output and render rings, daily metrics,
and the latest workout without relying on another data source.

## Manual work remaining

- create marketplace screenshots
- submit the TRMNL recipe
- optionally publish a packaged Docker image for self-hosted bridge users
