# TRMNL Apple Health

Display Apple Health data and activity rings on a TRMNL e-ink screen with a
webhook-strategy Private Plugin and the lightweight `TRMNLHealthSync` iPhone
app in this repo.

## Recommended architecture

Use one iPhone app against one Private Plugin:

```text
iPhone -> TRMNLHealthSync -> TRMNL Private Plugin -> display
```

`TRMNLHealthSync` reads the compact daily dashboard directly from HealthKit:
rings, steps, distance, flights, latest heart rate, sleep, and the latest
workout. Home Assistant and the self-hosted bridge remain optional.

For scheduled refreshes, add this app's `Sync Apple Health` action to a
Shortcuts automation.

## What it shows

- daily steps
- active energy
- latest heart rate
- sleep ending today
- latest workout
- Move, Exercise, and Stand activity rings
- walking/running distance
- flights climbed
- sync time

## Legacy bridge architecture

### Home Assistant mode

1. The iPhone app reads HealthKit.
2. The app registers with Home Assistant's native `mobile_app` API.
3. The app publishes a `Health Snapshot` sensor plus supporting sensors.
4. The HACS integration watches the snapshot sensor.
5. The integration pushes a debounced `merge_variables` payload to TRMNL.
6. TRMNL renders the bundled Liquid template.

### Self-hosted bridge mode

1. The iPhone app reads HealthKit.
2. The app pairs with the standalone bridge using a setup token.
3. The app sends the latest snapshot to the bridge.
4. The bridge stores it locally in SQLite.
5. The bridge pushes the normalized payload directly to TRMNL.
6. TRMNL renders the bundled Liquid template.

## Repo layout

- `custom_components/trmnl_health_bridge/`
  HACS-ready Home Assistant integration.
- `server/`
  Standalone self-hosted bridge with Docker packaging.
- `ios/TRMNLHealthSync/`
  iPhone app sources plus the Xcode project generator.
- `trmnl/`
  Single-app TRMNL markup plus recipe-publisher assets for the four TRMNL view sizes and custom field YAML.
- `docs/`
  Setup, architecture, privacy, and publishing notes.
- `scripts/generate_ios_project.rb`
  Generates the checked-in Xcode project from source files.
- `branding/`
  Source logo artwork.

## Recommended setup

1. In the TRMNL web app, create a `Private Plugin` using the `Webhook` strategy.
2. In the TRMNL Private Plugin editor, paste the matching layout templates from
   `trmnl/`.
3. Build and install `TRMNLHealthSync`, choose `TRMNL Direct`, paste the
   Private Plugin webhook URL, and tap `Connect TRMNL & Sync`.
4. Approve the requested HealthKit permissions.
5. Optionally create a Shortcuts automation that runs
   `TRMNL Health Sync -> Sync Apple Health`.

## Requirements

### Required

- An iPhone with Apple Health data
- A TRMNL device
- A TRMNL Private Plugin using the `Webhook` data strategy

### Optional server paths

- `Home Assistant mode`
  - Home Assistant
  - HACS
- `Self-hosted bridge mode`
  - Docker and Docker Compose on a local server, Raspberry Pi, mini PC, NAS, or VPS

### For building the iPhone app

- macOS
- Xcode
- An Apple Developer account if you want to install broadly, TestFlight, or publish to the App Store

## Optional self-hosted setup

## 1. Create the TRMNL plugin

1. In TRMNL, create a new `Private Plugin`.
2. Choose `Webhook` as the data strategy.
3. Click `Edit Markup`.
4. Paste the contents of `trmnl/apple-health-dashboard.liquid`.
5. Save the plugin once so TRMNL generates a webhook URL.
6. Copy the webhook URL. You will use it later.

Suggested plugin settings:

- Name: `Apple Health`
- Refresh interval: `15 minutes`
- Theme: a monochrome / e-ink-friendly option

If you are publishing this in the TRMNL marketplace instead of using it only as a private plugin, also use:

- `trmnl/apple-health-dashboard.fields.yaml` for the Custom Fields box
- `trmnl/apple-health-dashboard.liquid` for the `full` layout markup
- `trmnl/apple-health-dashboard.half_horizontal.liquid` for the `half_horizontal` layout markup
- `trmnl/apple-health-dashboard.half_vertical.liquid` for the `half_vertical` layout markup
- `trmnl/apple-health-dashboard.quadrant.liquid` for the `quadrant` layout markup
- `trmnl/apple-health-dashboard.transform.js` for the Node `Serverless` transform

## 2. Pick your server mode

Choose one:

- `Home Assistant mode`
- `Self-hosted bridge mode`

You can switch later. The iPhone app supports both.

## 3A. Home Assistant mode

1. In Home Assistant, install HACS if you do not already use it.
2. Add this repository as a custom HACS repository.
3. Install `TRMNL Health Bridge`.
4. Restart Home Assistant.
5. Go to `Settings -> Devices & Services -> Add Integration`.
6. Add `TRMNL Health Bridge`.
7. When prompted, enter:
   - the TRMNL webhook URL from step 1
   - the Apple Health snapshot sensor once the phone app has published it

If the phone app has not published its sensors yet, you can come back and finish the entity selection after step 5 below.

## 3B. Self-hosted bridge mode

1. Copy `docker-compose.example.yml` to `docker-compose.yml`.
2. Change `TRMNL_HEALTH_SETUP_TOKEN` to your own secret token.
3. Optionally set `TZ` to your local timezone.
4. Start the bridge:

```bash
docker compose up --build -d
```

5. Open the bridge in a browser:

```text
http://<your-server>:8421
```

6. Confirm the setup token shown there matches the one you configured.

If you want one shared TRMNL webhook for every device using this bridge, set `TRMNL_HEALTH_DEFAULT_TRMNL_WEBHOOK_URL` in your compose file.

## 4. Build the iPhone app

From the repo root:

```bash
ruby scripts/generate_ios_project.rb
```

Then:

1. Open `ios/TRMNLHealthSync/TRMNLHealthSync.xcodeproj`.
2. Select the `TRMNLHealthSync` target.
3. Set your signing team.
4. Confirm the bundle identifier is one you control.
5. Build and install on your iPhone.

## 5. Connect the app

Open the app on your iPhone.

### If you chose Home Assistant mode

Enter:

- your Home Assistant base URL
- a Home Assistant long-lived access token
- an optional device label

Tap `Connect Home Assistant & Sync`.

### If you chose Self-hosted bridge mode

Enter:

- your bridge URL
- the setup token
- the TRMNL webhook URL from step 1
- an optional device label

Tap `Connect Bridge & Sync`.

Then:

1. Approve Health access when iOS prompts you.
2. Wait for the initial sync to finish.
3. Use `Sync Now` any time you want to force an immediate refresh.

## 6. Finish Home Assistant mapping

Only for `Home Assistant mode`:

1. Go back to `TRMNL Health Bridge` in Home Assistant.
2. Select the entity whose friendly name is `Health Snapshot`.
3. Save the integration.

That sensor may look like:

- `sensor.health_snapshot`
- `sensor.<phone_name>_health_snapshot`

## 7. Confirm the result

You should now see:

- ring progress
- steps
- distance
- flights climbed
- sync time

on your TRMNL display after the next refresh.

## Daily use

- Run `Sync Apple Health` from Shortcuts on a schedule for predictable updates.
- The app also installs HealthKit observers and coalesces direct TRMNL updates
  to respect the webhook rate limit.
- Opening the app and tapping `Sync Now` will always force a refresh.
- In Home Assistant mode, the integration debounces updates to stay within TRMNL webhook limits.
- In self-hosted mode, the bridge stores the latest snapshot locally and pushes it out to TRMNL.

## Privacy model

The recommended path sends one compact Apple Health snapshot from
`TRMNLHealthSync` directly to the user's TRMNL Private Plugin.

The optional legacy paths add a self-hosted hop:

- In `Home Assistant mode`:
  `iPhone -> Home Assistant -> TRMNL`
- In `Self-hosted bridge mode`:
  `iPhone -> self-hosted bridge -> TRMNL`

The recommended direct path does not require:

- Home Assistant
- a self-hosted server
- public inbound access to the user's home network

See `docs/privacy.md` for the fuller privacy notes.

## Detailed docs

- `docs/setup.md`
  More setup detail.
- `docs/standalone-server.md`
  Standalone bridge environment variables and API.
- `docs/architecture.md`
  End-to-end architecture and payload contracts.
- `docs/privacy.md`
  Privacy posture.
- `docs/publishing.md`
  Publication roadmap and what still has to happen outside the repo.

## Current status

Implemented:

- single-app direct architecture and Shortcuts documentation
- HACS custom integration
- Standalone Docker-friendly bridge
- iPhone app with direct TRMNL, Home Assistant, and self-hosted bridge destinations
- discoverable `Sync Apple Health` Shortcuts action
- single-app TRMNL Liquid markup
- app icon/logo assets
- App Store-oriented entitlement cleanup and privacy manifest

Required before recipe publication:

- TRMNL marketplace submission

## Troubleshooting

### The Home Assistant integration says `Invalid handler specified`

Update to the latest version of the repo in HACS and restart Home Assistant.

### TRMNL says `Unsupported image format`

You likely used `Webhook Image (Experimental)` instead of a normal `Webhook` plugin. Use a regular `Private Plugin` with the `Webhook` data strategy.

### The iPhone app says the URL is invalid

Use a full base URL when possible, for example:

- `http://homeassistant.local:8123`
- `http://192.168.x.x:8421`

### The self-hosted bridge won’t install dependencies locally

If you install the Python dependencies outside Docker, use Python 3.13 or 3.12. The current dependency set is not happy on Python 3.14 yet.

## Publishing note

The intended public product story is:

- publish the TRMNL plugin
- direct users to install `TRMNLHealthSync`
- let users grant HealthKit read access in the app
- connect one Private Plugin webhook
- optionally run one sync action from Shortcuts
- retain Home Assistant and the standalone self-hosted bridge as optional legacy paths

This keeps setup small: one app, one webhook, and one optional automation.
