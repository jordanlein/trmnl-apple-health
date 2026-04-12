# Publishing Roadmap

This repo is now structured around a self-hosted publication path instead of a vendor-hosted health-data cloud.

## Phase 1: GitHub + TRMNL-ready assets

Implemented:

- public GitHub repo structure
- TRMNL Liquid markup
- setup docs for Home Assistant and standalone server

Manual work still required:

- final README polish
- screenshots for the marketplace listing
- TRMNL marketplace submission itself

## Phase 2: Regular self-hosted path

Implemented:

- HACS integration for Home Assistant users
- standalone Docker-friendly bridge for non-Home-Assistant users
- iPhone app support for both sync destinations

Manual work still required:

- packaged Docker image publishing
- optional install scripts beyond `docker compose`

## Phase 3: Tweaked productization path

This repo intentionally does **not** assume a vendor-hosted backend.

Instead, the publishable product story is:

- user runs Home Assistant or the standalone bridge
- iPhone app syncs only to infrastructure selected by the user
- the local server pushes the snapshot to TRMNL

That keeps health data custody on the user’s side while still allowing you to publish the TRMNL plugin and the iPhone client.

## Phase 4: App Store readiness

Implemented in code:

- only the HealthKit reads required for rings, steps, distance, flights, move, exercise, and stand
- no clinical Health Records entitlement
- no vendor-hosted health-data backend required by the architecture

Still required outside the repo:

- an App Store Connect app record
- screenshots, metadata, and category selection
- a published privacy policy URL
- a final App Review pass against the exact binary you submit

## App Store policy posture

The current design is strongest when presented as:

- a wellness / health-display companion
- user-directed syncing to the user’s own Home Assistant instance or self-hosted bridge
- no advertising, profiling, or resale of HealthKit data

Avoid positioning it as:

- a medical device
- a diagnostic app
- a cloud health-data platform
