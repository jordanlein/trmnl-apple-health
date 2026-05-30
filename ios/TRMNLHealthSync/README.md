# TRMNLHealthSync iOS app

This folder contains the checked-in Swift sources for the iPhone sync app.

Generate the Xcode project from the repo root:

```bash
ruby scripts/generate_ios_project.rb
```

The generated app:

- requests HealthKit read access
- computes a daily snapshot for rings, steps, distance, flights climbed, heart rate, sleep, and latest workout
- can deep-merge that compact snapshot directly into a TRMNL Private Plugin
- can sync to Home Assistant using the native `mobile_app` API
- can sync to the standalone self-hosted bridge over its local pairing API
- publishes Home Assistant sensors over the returned webhook when Home Assistant mode is selected
- exposes `Sync Apple Health` as a Shortcuts action
- installs HealthKit observers and coalesces direct webhook updates

Before building:

1. Open the generated project in Xcode.
2. Set your signing team.
3. Make sure the HealthKit capability is enabled for the app target.
