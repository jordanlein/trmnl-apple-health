# Standalone Server

The standalone bridge lets users run the project without Home Assistant.

## What it does

- pairs the iPhone app with a local setup token
- stores the latest Health snapshot in SQLite
- pushes updates directly to a TRMNL Private Plugin webhook
- exposes a tiny local dashboard plus JSON diagnostics endpoints

## Quick start

1. Copy `docker-compose.example.yml` to `docker-compose.yml`.
2. Change `TRMNL_HEALTH_SETUP_TOKEN`.
3. Optionally set `TZ`.
4. Start the server:

```bash
docker compose up --build -d
```

5. Open `http://<your-server>:8421`.
6. In the iPhone app, choose `Self-Hosted Bridge`.
7. Enter:
   - bridge URL
   - setup token
   - TRMNL webhook URL

## Environment variables

- `TRMNL_HEALTH_SETUP_TOKEN`
  Required. Shared secret used for initial app pairing.
- `TRMNL_HEALTH_DEFAULT_TRMNL_WEBHOOK_URL`
  Optional. If set, every paired device can omit its own TRMNL webhook URL.
- `TRMNL_HEALTH_SERVER_NAME`
  Optional. Displayed on the local dashboard.
- `TRMNL_HEALTH_DATA_DIR`
  Optional. Defaults to `/data`.
- `TRMNL_HEALTH_DB_PATH`
  Optional. Defaults to `/data/trmnl_health.db`.
- `TZ`
  Optional. Used for local time formatting in the TRMNL payload.

## API summary

- `POST /api/v1/devices/register`
  Pair one app install and receive a device token.
- `POST /api/v1/snapshots`
  Store the latest Health snapshot and push it to TRMNL. The request accepts a
  top-level `snapshot_status` value of `fresh` or `cached`; older clients that
  omit it remain compatible and default to `fresh`.
- `GET /api/v1/health`
  Healthcheck endpoint.
- `GET /api/v1/devices`
  List paired devices. Requires `X-Setup-Token`.
- `GET /api/v1/devices/{device_id}/latest`
  Fetch the latest stored snapshot. Requires `X-Setup-Token`.

## Notes

- The server is designed for self-hosting, not for running as a shared vendor cloud.
- TRMNL still receives only the rendered plugin payload, not direct access to the user’s HealthKit source.
- Because the bridge pushes out to TRMNL, users do not need to open inbound access to their home network.
- Cached snapshots retain their original capture time and are labeled as cached
  in every TRMNL layout, matching the direct-webhook behavior.
