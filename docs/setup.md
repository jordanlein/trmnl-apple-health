# Setup

## 1. Create the TRMNL Private Plugin

1. In TRMNL, create a new Private Plugin.
2. Choose the `Webhook` data strategy.
3. Paste the contents of `trmnl/apple-health-dashboard.liquid` into the markup editor.
4. Save the plugin once so TRMNL generates a webhook URL.

Suggested TRMNL settings:

- refresh interval: 15 minutes
- monochrome or 2-bit theme: whichever matches your device
- instance name: `Apple Health`

If you are submitting this to the TRMNL marketplace recipe publisher, map the repo files like this:

- `trmnl/apple-health-dashboard.fields.yaml` -> Custom Fields
- `trmnl/apple-health-dashboard.liquid` -> full layout
- `trmnl/apple-health-dashboard.half_horizontal.liquid` -> half_horizontal layout
- `trmnl/apple-health-dashboard.half_vertical.liquid` -> half_vertical layout
- `trmnl/apple-health-dashboard.quadrant.liquid` -> quadrant layout

## 2. Choose your server path

You can run this project in either of these modes:

- `Home Assistant`
- `Self-hosted bridge`

## 3A. Home Assistant path

1. Add this repository as a custom repository in HACS.
2. Install `TRMNL Health Bridge`.
3. Restart Home Assistant.
4. Go to `Settings -> Devices & Services -> Add Integration`.
5. Add `TRMNL Health Bridge`.

During config, you will need:

- the TRMNL Private Plugin webhook URL
- the Home Assistant sensor entity that ends with `health_sync_snapshot`

## 3B. Standalone self-hosted bridge path

1. Copy `docker-compose.example.yml` to `docker-compose.yml`.
2. Change `TRMNL_HEALTH_SETUP_TOKEN` to a private token.
3. Optionally set `TZ` to your local timezone.
4. Start the bridge:

```bash
docker compose up --build -d
```

5. Open the bridge in a browser, usually `http://<your-server>:8421`.
6. Confirm the setup token shown on the bridge matches the one you set in Docker.

See [standalone-server.md](standalone-server.md) for the full bridge details.

## 4. Build and install the iPhone app

1. From the repo root, run:

```bash
ruby scripts/generate_ios_project.rb
```

2. Open `ios/TRMNLHealthSync/TRMNLHealthSync.xcodeproj`.
3. Set your Apple signing team and bundle identifier if you want to personalize it.
4. Install the app on your iPhone.

## 5. Connect the app

In the app:

1. Choose `Home Assistant` or `Self-Hosted Bridge`.
2. Fill in the matching fields:
   - `Home Assistant`: base URL and long-lived token
   - `Self-Hosted Bridge`: bridge URL, setup token, and optionally the TRMNL webhook URL
3. Optionally rename the device label that will show up in Home Assistant, the bridge dashboard, and TRMNL.
4. Tap `Connect & Sync`.
5. Approve Health access when prompted.

The app will:

- register with the selected destination
- push an initial Health snapshot
- install HealthKit observers for later updates

## 6. Finish Home Assistant mapping

If you installed the integration before the app had published its sensor:

1. Re-open the `TRMNL Health Bridge` config entry.
2. Select the `Health Snapshot` sensor from your phone.
3. Save.

## Notes

- The app currently uses a Home Assistant long-lived token for initial registration instead of implementing the full Home Assistant OAuth/IndieAuth onboarding flow.
- In standalone mode, the app stores only the server setup token and per-device token locally in the iOS keychain.
- If you use Home Assistant Cloud, the app will prefer the returned cloudhook URL automatically after registration.
- TRMNL webhook requests are rate-limited; the Home Assistant integration debounces updates accordingly.
