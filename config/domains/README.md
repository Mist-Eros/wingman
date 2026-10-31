# Application profiles

One JSON file drives branding, feature switches, rewards and quorum for both the
Flutter app and the FastAPI backend.

- `airport.json` — Wingman (default; airport, one responder per primary dept,
  2/10 points).
- `events.json` — CrowdGuard example (stadium/event, fixed quorum, 1/5 credits).

## Use a profile

Flutter:

```powershell
flutter build apk --release `
  --dart-define=API_BASE=https://127.0.0.1:8443 `
  --dart-define=DOMAIN_CONFIG=config/domains/events.json
```

Backend (must use the same profile):

```powershell
$env:DOMAIN_CONFIG = "config/domains/events.json"
backend\run.ps1
```

If the file is missing/invalid, both sides fall back to the airport profile.

## Schema

```jsonc
{
  "schemaVersion": 1,
  "id": "airport",
  "branding": {
    "appName": "Wingman",
    "tagline": "Airport incident response · demo",
    "seedColor": "#1D4E89",
    "icon": "flight_takeoff"
  },
  "map": {
    "provider": "openstreetmap",
    "tileUrl": "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
    "attribution": "© OpenStreetMap contributors",
    "initialLat": 44.3189,
    "initialLng": 23.8864,
    "initialZoom": 15.5,
    "maxZoom": 19
  },
  "features": {
    "rewards": true,        // account/points entry point
    "gpsMap": true,         // live GPS map
    "photo": true,          // optional 5s photo prompt
    "accessibility": true,  // accessibility entry point
    "history": true,        // reserved: admin history
    "demoReset": true       // DevTools reset action
  },
  "quorum": {
    "strategy": "one_per_primary_department", // or "fixed"
    "minimum": 1,
    "fixed": 2
  },
  "rewards": {
    "strategy": "rule_based",
    "attendedPoints": 2,
    "resolvedBonus": 10,
    "deniedPoints": 0,
    "pointsLabel": "PUNCTE"
  },
  "notifications": {
    "roles": ["crew", "dispatcher"],
    "scope": "primary_departments"
  },
  "demo": {
    "seedTickets": 5,
    "resetEnabled": true
  }
}
```

`map.tileUrl` can point at any XYZ tile server (OpenStreetMap by default, or a
self-hosted one). Google Maps tiles require an API key/SDK and are not bundled;
the provider field is the seam for adding one.

Supported knobs are intentionally limited; unsupported concepts belong in a
policy class, not in the profile. See [docs/modularity.md](../../docs/modularity.md).
