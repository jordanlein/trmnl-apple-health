# Privacy Model

## Default posture

This project is designed so the user can keep their Apple Health data on infrastructure they control.

Supported paths:

- iPhone app -> Home Assistant -> TRMNL
- iPhone app -> self-hosted bridge -> TRMNL

## What the iPhone app reads

- steps
- walking/running distance
- flights climbed
- active energy burned
- exercise minutes
- stand hours
- activity goals and percentages

## What leaves the phone

Only the compact daily snapshot needed to render the TRMNL display leaves the phone.

That snapshot includes:

- timestamp
- device/profile label
- steps
- distance
- flights climbed
- move / exercise / stand values and goals

## What this repo does not require

- a vendor-hosted cloud
- advertising use of HealthKit data
- clinical record access
- public inbound access to the user’s home network

## Operational note

TRMNL still receives the rendered plugin data needed for the display, so users should treat the TRMNL webhook as sensitive configuration and keep their self-hosted bridge or Home Assistant instance private.
