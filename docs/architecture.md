# Architecture

## End-to-end flow

1. `TRMNLHealthSync` runs on iPhone, requests HealthKit read access, and computes a daily snapshot.
2. The app registers itself with Home Assistant's native `mobile_app` API and receives a webhook identity.
3. The app publishes one rich snapshot sensor plus a few human-readable metric sensors into Home Assistant.
4. `trmnl_health_bridge` watches the configured snapshot sensor for changes.
5. The Home Assistant integration coalesces updates, honors TRMNL webhook rate limits, and POSTs `merge_variables` to the TRMNL Private Plugin webhook URL.
6. TRMNL renders the checked-in Liquid template using the latest merged variables.

## Why this architecture

### TRMNL side

The provided TRMNL guide points to three main integration shapes:

- Private Plugin or Recipe
- Third-party OAuth plugin
- Direct Display / Device APIs

For a self-hosted Home Assistant install, a Private Plugin with webhook-backed `merge_variables` is the best fit:

- it avoids building a public OAuth-backed TRMNL SaaS service
- it avoids exposing Home Assistant to TRMNL polling traffic
- only the latest rendered screen matters, which maps well to a debounced health snapshot

### Home Assistant side

The user goal mentioned a Home Assistant add-on plus HACS, but those are different installation channels. HACS installs custom integrations; it does not install add-ons. To keep setup simple, the shipping implementation here is a HACS custom integration that runs inside Home Assistant Core.

That decision keeps the user path close to:

1. add the GitHub repo to HACS
2. install the integration
3. point it at the TRMNL webhook URL and the Health snapshot entity

An add-on can still be added later if you want stricter process isolation or a richer local preview service, but it is not required for the core bridge.

### iOS side

HealthKit data must be read on Apple hardware. Instead of inventing a custom internet-facing sync API, the app uses Home Assistant's native app registration flow:

- authenticated registration at `/api/mobile_app/registrations`
- webhook-based sensor updates after registration
- cloudhook / remote UI fallback if available

That gives us:

- no custom auth server
- no public Raspberry Pi ingress requirement
- native Home Assistant entities that users can also reuse in dashboards and automations

## HealthKit model

The app reads:

- steps
- walking/running distance
- flights climbed
- active energy burned
- exercise minutes
- stand hours
- activity summary goals for move, exercise, and stand

Important constraint: `HKActivitySummary` can be queried for ring progress and goals, but activity summaries are not the right background trigger primitive. The app therefore installs background delivery observers on the underlying quantity/category types and recomputes the full snapshot whenever HealthKit wakes it.

## Sync contract

### Home Assistant sensor contract

The iPhone app publishes a sensor with a state equal to the capture timestamp and attributes shaped like:

```json
{
  "captured_at": "2026-04-11T19:30:00Z",
  "date_label": "Sat, Apr 11",
  "device_name": "Jordan's iPhone",
  "profile_name": "Apple Health",
  "steps": 10432,
  "distance_km": 7.84,
  "distance_mi": 4.87,
  "flights_climbed": 12,
  "move_kcal": 612,
  "move_goal_kcal": 700,
  "move_percent": 87,
  "exercise_minutes": 41,
  "exercise_goal_minutes": 30,
  "exercise_percent": 137,
  "stand_hours": 11,
  "stand_goal_hours": 12,
  "stand_percent": 92
}
```

### TRMNL webhook contract

The Home Assistant integration POSTs:

```json
{
  "merge_strategy": "deep_merge",
  "merge_variables": {
    "profile_name": "Apple Health",
    "device_name": "Jordan's iPhone",
    "captured_at": "2026-04-11T19:30:00Z",
    "date_label": "Sat, Apr 11",
    "rings": {
      "move": 612,
      "move_goal": 700,
      "move_percent": 87,
      "exercise": 41,
      "exercise_goal": 30,
      "exercise_percent": 137,
      "stand": 11,
      "stand_goal": 12,
      "stand_percent": 92
    },
    "activity": {
      "steps": 10432,
      "distance_km": 7.84,
      "distance_mi": 4.87,
      "flights_climbed": 12
    }
  }
}
```

The Liquid template in `trmnl/` is written against that payload.

## Source links

- TRMNL guide you provided: local PDF in the project brief
- Home Assistant native app registration:
  [developers.home-assistant.io/docs/api/native-app-integration/setup](https://developers.home-assistant.io/docs/api/native-app-integration/setup)
- Home Assistant webhook sending:
  [developers.home-assistant.io/docs/api/native-app-integration/sending-data](https://developers.home-assistant.io/docs/api/native-app-integration/sending-data)
- Home Assistant custom sensors:
  [developers.home-assistant.io/docs/api/native-app-integration/sensors](https://developers.home-assistant.io/docs/api/native-app-integration/sensors)
- HACS add-on FAQ:
  [hacs.xyz/docs/faq/addons](https://hacs.xyz/docs/faq/addons)
- Apple HealthKit activity summary and predicates:
  [developer.apple.com/documentation/healthkit/hkobjecttype/activitysummarytype()](https://developer.apple.com/documentation/healthkit/hkobjecttype/activitysummarytype%28%29)
  [developer.apple.com/documentation/healthkit/hkquery](https://developer.apple.com/documentation/healthkit/hkquery)
