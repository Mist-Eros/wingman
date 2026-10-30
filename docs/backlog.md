# Backlog — agreed future requirements

## 1. Location gate ("only on airport premises")

**Decision:** required, but **after** the demo path is stable. Not in the H36 build unless
everything else is green.

### Requirement
Wingman must only be usable when the phone is physically near the airport. If the device is
outside the allowed radius, the app shows a blocking screen ("Wingman este disponibil doar în
incinta aeroportului") instead of the role picker.

### Design (proposal)
1. **Permission:** Android `ACCESS_FINE_LOCATION` (and `ACCESS_COARSE_LOCATION`), iOS
   `NSLocationWhenInUseUsageDescription`; runtime request via `permission_handler` (already
   compatible: `compileSdk = 37` is pinned in `android/app/build.gradle.kts`).
2. **Check:** haversine distance between device position and the airport anchor; allow if
   `distance <= radius`. Re-check on app start, on resume, and before submitting a report.
3. **Configuration (core, Lead-owned):**
   ```dart
   // lib/core/config/geofence.dart  (to add)
   const double kAirportLat = <to fill>;
   const double kAirportLng = <to fill>;
   const double kAirportRadiusMeters = 3000;
   const bool kGeofenceEnabled = true; // --dart-define=GEOFENCE=off disables for dev
   ```
4. **UX:** blocking screen with "Reîncearcă", the detected distance, and a note that location
   is used only for access control (no storage).
5. **Dev escape hatch (mandatory):** `--dart-define=BYPASS_GEOFENCE=true` for local
   development from home / emulator. Never enabled in the demo build; the bypass is compiled
   out of release profiles.
6. **Server hardening (optional, later):** `POST /api/reports` may accept
   `client_distance_m`; dispatcher shows "raportat de la X km"; a server flag can reject
   reports beyond the radius (defense in depth, since the client check is bypassable).

### Open questions to resolve before implementing
- Exact airport anchor coordinates + radius (terminal area vs whole perimeter; 1 km vs 3 km).
- Is the demo venue inside the radius? (Check at H36 — if not, the gate must be off for the
  demo or use "venue is the airport" for the story.)
- Should dispatchers see the reporter's distance in the ticket card? (nice trust signal)
- Permission denied → hard block or read-only mode? (proposal: hard block with instructions)

### Effort
~2-3 h: core geofence util + tests, permission wiring, blocking screen in `main.dart`,
Android/iOS plists. Add to the timeline after H36 only if the demo is already recorded.

## 2. Other ideas parked for later
- Persist tickets to SQLite on the backend (survive restarts; currently in-memory).
- Reporter audio attachment (store the recorded clip, replay in dispatcher card).
- Push notifications (FCM/APNs) instead of relying on a foreground WSS socket.
- Basic auth: real accounts instead of the role picker (short-lived tokens, mTLS).
