# TRMNL Apple Health Bridge

This repository is a greenfield implementation for getting Apple Health data onto a TRMNL e-ink display with the fewest moving parts that still fit the platform constraints.

The shipping path in this repo is:

1. An iPhone app reads HealthKit and publishes a compact daily snapshot into Home Assistant using the native `mobile_app` sensor/webhook API.
2. A Home Assistant custom integration installed through HACS watches that snapshot sensor and pushes a debounced webhook payload to a TRMNL Private Plugin.
3. TRMNL renders the supplied Liquid/HTML markup on its normal wake cycle.

Why this shape:

- HealthKit data has to originate on iPhone or Apple Watch hardware.
- TRMNL Private Plugin webhooks avoid making Home Assistant publicly reachable by TRMNL.
- HACS installs custom integrations, not Home Assistant add-ons, so the simplest install path lives in `custom_components/`.

## Repo layout

- `custom_components/trmnl_health_bridge/`: HACS-ready Home Assistant integration
- `ios/TRMNLHealthSync/`: iPhone companion app sources plus an Xcode project generator
- `trmnl/`: ready-to-paste TRMNL Private Plugin markup
- `docs/`: architecture and setup notes
- `scripts/generate_ios_project.rb`: emits a real Xcode project from the checked-in app sources

## Current scope

Implemented in this scaffold:

- HealthKit snapshot model for steps, distance, flights climbed, move ring, exercise ring, and stand ring
- Home Assistant native app registration and sensor publishing
- Home Assistant config flow that points at one Health snapshot sensor and one TRMNL webhook URL
- Debounced TRMNL webhook pushing with rate limiting aligned to TRMNL standard vs TRMNL+ webhook limits
- A TRMNL Private Plugin template that renders the snapshot cleanly on e-ink

Not yet included:

- App Store/TestFlight distribution
- A separate Home Assistant add-on container
- Multi-user sync orchestration beyond one snapshot entity per config entry

## Quick start

1. Read [docs/setup.md](docs/setup.md).
2. Install the Home Assistant integration through HACS.
3. Generate the iOS project with `ruby scripts/generate_ios_project.rb`.
4. Open `ios/TRMNLHealthSync/TRMNLHealthSync.xcodeproj` in Xcode, set your signing team, and install the app on your iPhone.
5. Create a TRMNL Private Plugin using `trmnl/apple-health-dashboard.liquid`.

## Source-backed decisions

The most important architecture choices here are documented in [docs/architecture.md](docs/architecture.md), including:

- why this uses TRMNL Private Plugin webhooks instead of a third-party TRMNL OAuth server
- why the Home Assistant piece ships as a HACS custom integration instead of an add-on
- why the iPhone app uses Home Assistant native app registration instead of a custom public API
