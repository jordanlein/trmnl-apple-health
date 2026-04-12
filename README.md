# TRMNL Apple Health Bridge

This repository is a product-ready foundation for getting Apple Health data onto a TRMNL e-ink display without forcing users onto one hosting model.

The repo now supports two shipping paths:

1. `Home Assistant mode`
   The iPhone app reads HealthKit, publishes a compact daily snapshot into Home Assistant, and the HACS integration pushes debounced updates to TRMNL.
2. `Self-hosted bridge mode`
   The iPhone app reads HealthKit, syncs to a tiny Docker-friendly local bridge, and that bridge pushes directly to TRMNL.

Why this shape:

- HealthKit data has to originate on iPhone or Apple Watch hardware.
- TRMNL Private Plugin webhooks avoid making a home server publicly reachable by TRMNL.
- HACS installs custom integrations, not Home Assistant add-ons, so the Home Assistant path lives in `custom_components/`.
- A standalone bridge keeps the data path self-hosted for users who do not want to use Home Assistant.

## Repo layout

- `custom_components/trmnl_health_bridge/`: HACS-ready Home Assistant integration
- `server/`: standalone self-hosted bridge with Docker packaging
- `ios/TRMNLHealthSync/`: iPhone companion app sources plus an Xcode project generator
- `trmnl/`: ready-to-paste TRMNL Private Plugin markup
- `docs/`: architecture and setup notes
- `scripts/generate_ios_project.rb`: emits a real Xcode project from the checked-in app sources

## Current scope

Implemented in this scaffold:

- HealthKit snapshot model for steps, distance, flights climbed, move ring, exercise ring, and stand ring
- Home Assistant native app registration and sensor publishing
- A standalone self-hosted bridge with pairing tokens, local persistence, and direct TRMNL webhook pushing
- Home Assistant config flow that points at one Health snapshot sensor and one TRMNL webhook URL
- Debounced TRMNL webhook pushing with rate limiting aligned to TRMNL standard vs TRMNL+ webhook limits
- A TRMNL Private Plugin template that renders the snapshot cleanly on e-ink

Prepared, but still requiring account-level submission work outside this repo:

- App Store / TestFlight submission in App Store Connect
- TRMNL marketplace submission
- Turnkey installers beyond Docker and Home Assistant

## Quick start

1. Read [docs/setup.md](docs/setup.md).
2. Choose either the HACS path or the standalone Docker bridge path.
3. Generate the iOS project with `ruby scripts/generate_ios_project.rb`.
4. Open `ios/TRMNLHealthSync/TRMNLHealthSync.xcodeproj` in Xcode, set your signing team, and install the app on your iPhone.
5. Create a TRMNL Private Plugin using `trmnl/apple-health-dashboard.liquid`.

## Source-backed decisions

The most important architecture choices here are documented in [docs/architecture.md](docs/architecture.md), including:

- why this uses TRMNL Private Plugin webhooks instead of a third-party TRMNL OAuth server
- why the Home Assistant piece ships as a HACS custom integration instead of an add-on
- why the standalone bridge exists as a second sync target
- why the iPhone app now supports both Home Assistant and self-hosted bridge registration
