# Modularity guide

Wingman is now split into **one application profile + small policy modules +
feature modules**. The goal is straightforward: a different venue/vertical
should be mostly a config change, and a different **rule** should be one class
with its own tests — not an edit across screens.

## High-level shape

```
config/domains/airport.json          ← the app profile (branding, features, rewards, quorum)
        │
        ├── Flutter DomainConfig  (lib/core/domain/domain_config.dart)
        │       ├── branding / tagline / seed colour
        │       ├── feature switches (rewards, gpsMap, photo, accessibility, history, demoReset)
        │       ├── RewardConfig  ──► RewardService ──► AccountScreen
        │       └── QuorumConfig  ──► QuorumPolicy
        │
        └── FastAPI domain        (backend/app/domain.py)
                ├── same profile loaded through DOMAIN_CONFIG
                ├── QuorumConfig.required_for(...) used by TicketStore.create
                └── DomainConfig.reward_ledger(...) exposed at /api/accounts/{id}/rewards

Core policies/services
  core/rewards/              RewardPolicy + ledger + RewardService
  core/domain/               DomainConfig + QuorumPolicy
  core/demo/                 demo reset service
  core/notifications/        alert rules + local notifier

Feature modules
  features/rewards/          account UI only (renders the ledger)
  core/widgets/ticket_media_panel.dart  Foto/Hartă toggle, reusable on any ticket surface
  features/reporter/         reporting screens, menu, GPS, photo
  features/dispatcher/       admin queue/history
  features/crew/             crew queue
  core/accessibility/        global accessibility profiles
```

`CoreScope` is still the only dependency-injection point; it now also carries
`DomainConfig`, `RewardService` and `DemoResetService`, so screens never construct
policies themselves.

## What can change with just the JSON profile

| Key | Effect |
|---|---|
| `branding.appName`, `tagline`, `seedColor` | login title/tagline, Material seed colour, API status page |
| `features.rewards` | hides the account/points entry point |
| `features.gpsMap` | hides the live GPS map entry point |
| `map.tileUrl` / `map.initialLat/Lng` | real tile map provider and airport/venue centre |
| `features.photo` | disables the optional 5-second photo prompt |
| `features.accessibility` | hides the accessibility entry point |
| `features.history` | hides the admin History tab |
| `features.demoReset` | hides the demo-reset action |
| `rewards.reportPoints` (2), `attendedPoints` (0), `resolvedBonus` (5 = join+solve), `deniedPoints`, `pointsLabel` | reward ledger and account header |
| `quorum.strategy`, `minimum`, `fixed` | responder count required by the server |
| `notifications.roles` | which roles may receive alerts (`crew`, `dispatcher`) |
| `demo.seedTickets`, `demo.resetEnabled` | reserved for seed tooling / reset UI |

Example profile: `config/domains/events.json` (CrowdGuard, fixed quorum, 1/5
credits). It is bundled too, so the app can be built against it directly.

## Reuse for another application

1. Copy a profile:

   ```powershell
   Copy-Item config/domains/airport.json config/domains/stadium.json
   ```

2. Edit branding, `features`, `rewards`, `quorum`.

3. Run the backend against the same file:

   ```powershell
   $env:DOMAIN_CONFIG = "config/domains/stadium.json"
   backend\run.ps1
   ```

4. Build the app against it:

   ```powershell
   flutter build apk --release `
     --dart-define=API_BASE=https://127.0.0.1:8443 `
     --dart-define=DOMAIN_CONFIG=config/domains/stadium.json
   ```

No route, screen or store code has to change for the supported knobs.

## Changing rules (code extension points)

### Rewards

- Edit the JSON for the standard rule-based scheme.
- For a completely different scheme, implement `RewardPolicy` in
  `lib/core/rewards/reward_policy.dart` and inject it:

  ```dart
  CoreScope.rewardService: RewardService(policy: MyShiftRewardPolicy())
  ```

  The Account screen only consumes `RewardLedger`, so it keeps working.
- Backend equivalent: add a policy to `backend/app/domain.py` and have
  `AccountScreen`/web clients read `/api/accounts/{crewId}/rewards` if you want
  the server to be the source of truth.

### Quorum

- `one_per_primary_department` (default): one responder per primary department.
- `fixed`: a fixed number of responders.
- Add a strategy in both:
  - `lib/core/domain/quorum_policy.dart`
  - `backend/app/domain.py` (`QuorumConfig.required_for`)
  
  Then select it with `quorum.strategy` in the JSON.

### Notifications

`TicketAlertRules` in `core/notifications/ticket_notifier.dart` is built from
`notifications.roles` in the profile. Add roles/scopes there or implement a
different rule class; the notifier itself stays untouched.

### Demo reset

`DemoResetService` wraps `devReset + board.refresh`; DevTools (or a future admin
screen) calls it. A different application can replace it through
`CoreScope.demoResetService`.

## Backend contract

- `GET /api/domain` — active profile (safe, no secrets)
- `GET /api/accounts/{crew_id}/rewards` — reward ledger from the same policy
  - `totalPoints`, `attendedCount`, `resolvedCount`, `inProgressCount`,
    `pointsLabel`, `entries[]`
- `/health` now exposes `domain`, `quorum_strategy`, `reward_strategy` and
  reward config.

## Still domain-specific (next boundaries)

These are intentionally called out rather than hidden:

- **Incident catalog**: `core/incidents/taxonomy.dart` and the generated
  8×8×8 menu in `features/reporter/menu/incident_menu_data.dart`. A hospital or
  stadium needs its own catalog; extract an `IncidentCatalog` interface next.
- **Demo accounts / roles**: `core/auth/demo_accounts.dart` is still hardcoded.
- **Localisation**: Romanian/English strings are per-feature (`tr(...)`).
- **Waterfox dashboard**: the static HTML has its own copy of the visual language
  and admin history; it is a separate presentation target.

## Verify

```powershell
flutter analyze
flutter test
backend\.venv\Scripts\python.exe -m unittest discover -s backend\tests -v
python scripts\smoke_test.py --base https://127.0.0.1:8443
```
