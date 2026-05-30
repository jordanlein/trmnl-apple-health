# Privacy Model

## Default posture

The recommended path is direct:

```text
iPhone -> TRMNLHealthSync -> TRMNL Private Plugin -> display
```

The user grants HealthKit read permission in the app. The app sends one compact
dashboard snapshot to the configured TRMNL webhook.

## What the app reads

- Move, Exercise, and Stand rings and goals
- steps
- walking/running distance
- flights climbed
- latest heart-rate sample
- recent sleep duration
- latest workout summary

## What the app sends

Only the values required for the TRMNL dashboard leave the phone:

- timestamp and device/profile label
- ring values, goals, and percentages
- daily activity totals
- latest heart rate
- sleep duration
- latest workout type, date, duration, and active energy

The app does not upload complete HealthKit sample histories.

## Optional bridge paths

Users may intentionally choose:

- `iPhone -> Home Assistant -> TRMNL`
- `iPhone -> self-hosted bridge -> TRMNL`

Direct mode does not require Home Assistant, a self-hosted server, or public
inbound access to a home network. Treat the TRMNL webhook URL as a secret.
