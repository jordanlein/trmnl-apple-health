"""FastAPI entrypoint for the standalone self-hosted bridge."""

from __future__ import annotations

from datetime import UTC, datetime
import hashlib
import secrets

from fastapi import Depends, FastAPI, Header, HTTPException, Query, status
from fastapi.responses import HTMLResponse

from .config import Settings, load_settings
from .models import (
    DeviceRegistrationRequest,
    DeviceRegistrationResponse,
    DeviceSummary,
    SnapshotUpdateRequest,
    SnapshotUpdateResponse,
)
from .storage import Storage
from .trmnl import build_merge_variables, push_to_trmnl

settings = load_settings()
storage = Storage(settings.database_path)

app = FastAPI(
    title="TRMNL Health Bridge",
    version="0.3.0",
    summary="Self-hosted bridge for syncing Apple Health snapshots to TRMNL.",
)


def _hash_token(value: str) -> str:
    """Hash device tokens before storing them."""
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def _require_setup_token(token: str | None) -> str:
    """Validate the admin/setup token."""
    if not token or not secrets.compare_digest(token, settings.setup_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A valid X-Setup-Token header is required.",
        )
    return token


def _setup_token_dependency(
    token: str | None = Header(default=None, alias="X-Setup-Token"),
) -> str:
    """FastAPI dependency wrapper for the admin setup token."""
    return _require_setup_token(token)


def _require_device(authorization: str | None) -> object:
    """Resolve the bearer token into a paired device row."""
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="A bearer device token is required.",
        )

    token = authorization.split(" ", 1)[1].strip()
    device = storage.get_device_by_token_hash(_hash_token(token))
    if device is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The device token is invalid.",
        )
    return device


def _device_dependency(authorization: str | None = Header(default=None)) -> object:
    """FastAPI dependency wrapper for bearer device tokens."""
    return _require_device(authorization)


@app.on_event("startup")
def startup() -> None:
    """Ensure the database schema exists before serving requests."""
    storage.initialize()


@app.get("/api/v1/health")
def healthcheck() -> dict[str, object]:
    """Basic health endpoint for Docker and reverse proxy probes."""
    return {
        "ok": True,
        "server_name": settings.server_name,
        "timezone": settings.timezone_name,
        "devices": len(storage.list_devices()),
    }


@app.get("/", response_class=HTMLResponse)
def dashboard() -> HTMLResponse:
    """Tiny local dashboard for setup confirmation and diagnostics."""
    devices = storage.list_devices()
    return HTMLResponse(_render_dashboard(settings, devices))


@app.post("/api/v1/devices/register", response_model=DeviceRegistrationResponse)
def register_device(payload: DeviceRegistrationRequest) -> DeviceRegistrationResponse:
    """Pair one app install with the bridge and return a device token."""
    if not secrets.compare_digest(payload.setup_token, settings.setup_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="The setup token is invalid.",
        )

    registered_at = datetime.now(tz=UTC)
    device_token = secrets.token_urlsafe(32)
    storage.register_device(
        payload=payload,
        token_hash=_hash_token(device_token),
        registered_at=registered_at,
    )
    return DeviceRegistrationResponse(
        device_id=payload.device_id,
        device_name=payload.device_name,
        profile_name=payload.profile_name,
        device_token=device_token,
        trmnl_webhook_configured=bool(payload.trmnl_webhook_url),
        default_trmnl_webhook_configured=bool(settings.default_trmnl_webhook_url),
        registered_at=registered_at,
    )


@app.post("/api/v1/snapshots", response_model=SnapshotUpdateResponse)
def update_snapshot(
    payload: SnapshotUpdateRequest,
    device: object = Depends(_device_dependency),
) -> SnapshotUpdateResponse:
    """Store the latest Health snapshot and optionally push it to TRMNL."""
    stored_at = datetime.now(tz=UTC)
    snapshot = payload.normalized_snapshot()
    effective_webhook = (
        payload.trmnl_webhook_url
        or device["trmnl_webhook_url"]
        or settings.default_trmnl_webhook_url
    )
    storage.save_snapshot(
        device_id=device["device_id"],
        snapshot=snapshot,
        trmnl_webhook_url=payload.trmnl_webhook_url,
        stored_at=stored_at,
    )

    pushed_to_trmnl = False
    push_error = None
    if effective_webhook:
        pushed_to_trmnl, push_error = push_to_trmnl(
            effective_webhook,
            build_merge_variables(snapshot, settings.timezone_name),
        )

    return SnapshotUpdateResponse(
        device_id=device["device_id"],
        stored_at=stored_at,
        pushed_to_trmnl=pushed_to_trmnl,
        trmnl_webhook_configured=bool(effective_webhook),
        trmnl_push_error=push_error,
    )


@app.get("/api/v1/devices", response_model=list[DeviceSummary])
def list_devices(
    _: str = Depends(_setup_token_dependency),
) -> list[DeviceSummary]:
    """List paired devices and their latest snapshots."""
    return storage.list_devices()


@app.get("/api/v1/devices/{device_id}/latest")
def latest_snapshot(
    device_id: str,
    _: str = Depends(_setup_token_dependency),
    format: str = Query(default="raw", pattern="^(raw|trmnl)$"),
) -> dict[str, object]:
    """Return the latest stored snapshot, optionally in TRMNL merge format."""
    device = storage.get_device(device_id)
    if device is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Unknown device.")

    latest = storage.latest_snapshot(device_id)
    if latest is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No snapshot has been synced yet.",
        )

    snapshot, stored_at = latest
    if format == "trmnl":
        return {
            "merge_variables": build_merge_variables(snapshot, settings.timezone_name),
        }

    return {
        "device_id": device_id,
        "stored_at": stored_at,
        "snapshot": snapshot,
    }


def _render_dashboard(settings: Settings, devices: list[DeviceSummary]) -> str:
    """Render a minimal diagnostics dashboard without a template dependency."""
    cards = []
    for device in devices:
        snapshot = device.latest_snapshot
        if snapshot is None:
            detail = "<p>No sync yet.</p>"
        else:
            detail = (
                f"<p><strong>{snapshot.steps}</strong> steps</p>"
                f"<p>{snapshot.move_kilocalories}/{snapshot.move_goal_kilocalories} kcal move</p>"
                f"<p>{snapshot.exercise_minutes}/{snapshot.exercise_goal_minutes} min exercise</p>"
                f"<p>{snapshot.stand_hours}/{snapshot.stand_goal_hours} hr stand</p>"
                f"<p>Snapshot source: {snapshot.snapshot_status}</p>"
            )
        cards.append(
            f"""
            <article class="card">
              <h2>{device.device_name}</h2>
              <p class="meta">{device.profile_name} · {device.device_id}</p>
              <p class="meta">TRMNL webhook: {"configured" if device.trmnl_webhook_configured else "not configured"}</p>
              <p class="meta">Last sync: {device.last_sync_at or "never"}</p>
              {detail}
            </article>
            """
        )

    devices_markup = "\n".join(cards) if cards else "<p>No devices have paired yet.</p>"
    return f"""
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>{settings.server_name}</title>
        <style>
          :root {{
            color-scheme: light;
            --bg: #f3f0ea;
            --card: #fffdfa;
            --ink: #171311;
            --muted: #70675f;
            --line: #dbd2c8;
          }}
          body {{
            margin: 0;
            font-family: ui-sans-serif, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: radial-gradient(circle at top, #fffdf7, var(--bg) 56%);
            color: var(--ink);
          }}
          main {{
            max-width: 880px;
            margin: 0 auto;
            padding: 32px 20px 48px;
          }}
          h1 {{
            margin-bottom: 8px;
            font-size: 2rem;
          }}
          p {{
            margin: 0 0 8px;
            line-height: 1.5;
          }}
          .meta {{
            color: var(--muted);
            font-size: 0.95rem;
          }}
          .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
            gap: 16px;
            margin-top: 24px;
          }}
          .card {{
            border: 1px solid var(--line);
            border-radius: 18px;
            background: var(--card);
            padding: 18px;
            box-shadow: 0 8px 22px rgba(23, 19, 17, 0.04);
          }}
          code {{
            font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
            background: rgba(23, 19, 17, 0.05);
            padding: 2px 6px;
            border-radius: 6px;
          }}
        </style>
      </head>
      <body>
        <main>
          <h1>{settings.server_name}</h1>
          <p class="meta">Self-hosted Apple Health → TRMNL bridge</p>
          <p>Use your iPhone app to register against this server with the setup token, then paste a TRMNL webhook URL into the app for direct pushes.</p>
          <p><strong>Setup token:</strong> <code>{settings.setup_token}</code></p>
          <p><strong>Default TRMNL webhook:</strong> <code>{settings.default_trmnl_webhook_url or "not configured"}</code></p>
          <p><strong>Health endpoint:</strong> <code>/api/v1/health</code></p>
          <div class="grid">
            {devices_markup}
          </div>
        </main>
      </body>
    </html>
    """
