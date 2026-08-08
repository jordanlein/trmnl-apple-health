# Architecture

## Recommended flow

```text
iPhone -> TRMNLHealthSync -> TRMNL Private Plugin -> display
```

1. The user creates a Private Plugin with the `Webhook` strategy.
2. The user connects its webhook URL in `TRMNLHealthSync`.
3. The app requests HealthKit read permissions and computes one compact daily
   snapshot.
4. The app deep-merges that snapshot into the plugin.
5. TRMNL renders the checked-in Liquid layout.

The same sync is available through the `Sync Apple Health` App Intent.

## HealthKit model

The app reads:

- activity summary goals and progress for Move, Exercise, and Stand
- steps
- walking/running distance
- flights climbed
- latest heart-rate sample
- recent asleep samples
- latest workout summary

HealthKit observers wake the app when underlying sample types change. The app
recomputes the snapshot and coalesces direct webhook pushes to respect TRMNL
rate limits.

## TRMNL webhook contract

```json
{
  "merge_variables": {
    "profile_name": "Apple Health",
    "device_name": "Jordan's iPhone",
    "captured_at": "2026-05-30T16:22:00Z",
    "sync_time_label": "11:22 AM",
    "date_label": "Sat, May 30",
    "snapshot_status": "fresh",
    "rings": {
      "move": 428,
      "move_goal": 500,
      "move_percent": 86,
      "exercise": 24,
      "exercise_goal": 30,
      "exercise_percent": 80,
      "stand": 9,
      "stand_goal": 12,
      "stand_percent": 75
    },
    "activity": {
      "steps": 7314,
      "distance_km": 5.82,
      "distance_mi": 3.62,
      "flights_climbed": 8
    },
    "health": {
      "latest_heart_rate_bpm": 72,
      "sleep_hours": 7.4,
      "latest_workout": {
        "activity_type": "Running",
        "start_date": "2026-05-30T13:15:00Z",
        "duration_seconds": 1920,
        "total_energy_burned_kilocalories": 286
      }
    }
  }
}
```

## Optional bridge paths

The same snapshot also supports:

- Home Assistant native app registration and sensor updates
- self-hosted bridge pairing and bearer-token snapshot updates

These paths are retained for users who intentionally want a local hop. They
are not required for the normal setup. Both optional paths preserve the
snapshot's original timestamp and `fresh`/`cached` source status, so a locked
phone fallback is labeled the same way as a direct webhook update.

## Source links

- [TRMNL Private Plugins](https://help.trmnl.com/en/articles/9510536-private-plugins)
- [TRMNL Liquid 101](https://help.trmnl.com/en/articles/10671186-liquid-101)
- [TRMNL webhook documentation](https://docs.trmnl.com/go/private-plugins/webhooks)
- [Apple App Intents](https://developer.apple.com/documentation/appintents/app-intents)
- [Apple HKActivitySummary](https://developer.apple.com/documentation/healthkit/hkactivitysummary)
- [Apple HealthKit](https://developer.apple.com/documentation/healthkit)
