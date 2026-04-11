# Setup

## 1. Install the Home Assistant side

1. Add this repository as a custom repository in HACS.
2. Install `TRMNL Health Bridge`.
3. Restart Home Assistant.
4. Go to `Settings -> Devices & Services -> Add Integration`.
5. Add `TRMNL Health Bridge`.

During config, you will need:

- the TRMNL Private Plugin webhook URL
- the Home Assistant sensor entity that ends with `health_sync_snapshot`

## 2. Create the TRMNL Private Plugin

1. In TRMNL, create a new Private Plugin.
2. Choose the `Webhook` data strategy.
3. Paste the contents of `trmnl/apple-health-dashboard.liquid` into the markup editor.
4. Save the plugin once so TRMNL generates a webhook URL.
5. Copy that webhook URL into the Home Assistant integration config flow.

Suggested TRMNL settings:

- refresh interval: 15 minutes
- monochrome or 2-bit theme: whichever matches your device
- instance name: `Apple Health`

## 3. Build and install the iPhone app

1. From the repo root, run:

```bash
ruby scripts/generate_ios_project.rb
```

2. Open `ios/TRMNLHealthSync/TRMNLHealthSync.xcodeproj`.
3. Set your Apple signing team and bundle identifier if you want to personalize it.
4. Install the app on your iPhone.

## 4. Connect the app

In the app:

1. Enter your Home Assistant base URL.
2. Enter a Home Assistant long-lived access token.
3. Optionally rename the device label that will show up in Home Assistant and TRMNL.
4. Tap `Connect & Sync`.
5. Approve Health access when prompted.

The app will:

- register with Home Assistant's `mobile_app` API
- publish the Health snapshot entity
- push an initial sensor update
- install HealthKit observers for later updates

## 5. Finish Home Assistant mapping

If you installed the integration before the app had published its sensor:

1. Re-open the `TRMNL Health Bridge` config entry.
2. Select the `Health Snapshot` sensor from your phone.
3. Save.

## Notes

- The app currently uses a Home Assistant long-lived token for initial registration instead of implementing the full Home Assistant OAuth/IndieAuth onboarding flow.
- If you use Home Assistant Cloud, the app will prefer the returned cloudhook URL automatically after registration.
- TRMNL webhook requests are rate-limited; the Home Assistant integration debounces updates accordingly.
