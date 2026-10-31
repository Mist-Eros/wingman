# Wingman — airport incident response (demo)

Staff report an incident by **voice or a button menu**; a **local Ollama model** classifies it
into a closed 14-type taxonomy; the FastAPI backend assigns **urgency + departments**, broadcasts
over **WSS** to a dispatcher dashboard and crew phones, and routes **Android notifications only to
the departments the incident needs**. Tickets go straight to the dispatcher, who can **deny or
reclassify** any of them; crews **join** and **vote** to resolve. Everything runs on the laptop —
no cloud, TLS with a private pinned CA, in-memory store.

**Status:** demo-ready. `flutter analyze` clean · **160 app tests** · backend smoke **101/101** ·
`scripts\verify_all.ps1 -Live` → ALL GATES PASSED.

---

## 1. Quick start

```powershell
# 1) backend (TLS :8443) — first run installs Python deps
cd backend; .\run.ps1

# 2) seed the stage data + prove the API
cd ..; python backend\seed_demo.py
python scripts\smoke_test.py --ca backend\certs\ca.crt     # 101/101

# 3) phone (Android; APK is built by the script)
.\scripts\build_demo_apks.ps1 -ApiHost <LAPTOP_IP>
adb install -r D:\Hackathon\dist\wingman-tls-release.apk

# 4) desktop control room (Waterfox)
.\scripts\serve_dashboard.ps1

# 5) one command for every gate
.\scripts\verify_all.ps1 -Live
```

Networking, certificates and phone setup: [docs/laptop-setup.md](docs/laptop-setup.md),
[docs/certs-and-phones.md](docs/certs-and-phones.md), [docs/phone-testing.md](docs/phone-testing.md).
Rehearsal script: [docs/demo-script.md](docs/demo-script.md).

---

## 2. Demo accounts

Hardcoded, passwords stored as salted SHA-256; the scope decides who gets alerted. **Anyone can
report** — there is no separate reporter account.

| Account | Password | Scope |
|---|---|---|
| Andy Admin | `admin123` | everything + dispatcher dashboard |
| Earl Engineer | `engineer123` | maintenance / IT / baggage / airside |
| John Janitor | `janitor123` | terminal services |
| Fred Firefighter | `firefighter123` | fire / rescue |
| Gina Guard | `guard123` | security |

---

## 3. Project layout

```text
Wingman/                         Flutter project (Android + iOS) + Python backend
├── lib/
│   ├── main.dart                app bootstrap, routes, session, notifications wiring
│   ├── core/                    shared contracts (owned by Lead)
│   │   ├── api/                 REST + WSS client (dart:io, pinned TLS)
│   │   ├── auth/                demo accounts, session/token stores
│   │   ├── incidents/           taxonomy — single source of truth (14 types)
│   │   ├── models/              Ticket, Session, AnalyzeResult, Transcription
│   │   ├── notifications/       department-scoped local notification policy
│   │   ├── state/               TicketBoard (snapshot + WSS merge)
│   │   ├── theme/               Wingman design system (navy airport ops)
│   │   └── widgets/             time-of-day sky background
│   ├── features/
│   │   ├── auth/                login + account chooser
│   │   ├── dev/                 DevTools (sky preview, health, demo actions)
│   │   ├── reporter/            voice/typed report flow + local conversation brain
│   │   ├── dispatcher/          live dashboard, open queue + filters
│   │   └── crew/                scoped queue, join, resolve vote
│   ├── web_dashboard_main.dart  optional Flutter-web control room (Chromium only)
│   └── features/crew/crew_preview_main.dart  local preview of the crew UI (no backend)
├── backend/
│   ├── app/                     FastAPI: routes, Ollama, Whisper, store, taxonomy
│   │   └── data/occurrences.json  source-backed incident database (59 entries)
│   ├── seed_demo.py             seeds the 5 rehearsal tickets
│   └── run.ps1 / run_insecure.ps1
├── assets/certs/ca.crt          public CA bundle pinned by the app
├── tool/emit_taxonomy.dart      taxonomy generator (backend/taxonomy.json)
├── scripts/                     certificates, builds, dashboard, gates (see scripts/README.md)
├── docs/                        project docs (see docs/README.md)
├── test/                        app contract + live + widget tests
└── CONTRACTS.md                 frozen wire contracts (Dart ↔ FastAPI)
```

---

## 4. How it works

```text
 phone (voice/menu)                         crew phones
        │ POST /api/reports                       ▲ WSS ticket.* + notifications
        ▼                                         │
  FastAPI :8443  ── Ollama qwen2.5:1.5b ──▶ classification + urgency + departments
        │          ── Whisper (faster-whisper) for STT
        ▼
  in-memory store: status machine · immediate dispatch · join · vote quorum
        │
        ▼ REST + WSS
  Waterfox control room (PC)  ── report form · live queue · confirm/deny/reclassify
```

* **AI policy — dispatch first.** The only questions are for a missing **type** or **location**.
  There is no “is anyone in danger?” or “describe it” question: high-stakes reports go to the
  dispatcher immediately and can be denied or reclassified from the queue.
* **Incident catalog**: 59 source-backed occurrences (EU 2015/1018 + ASRS + ground-handling guidance) mapped onto the 14 operational codes — served by `GET /api/occurrences`, documented in [docs/occurrence-catalog.md](docs/occurrence-catalog.md).
* **Locations** are free text and matched against a Craiova airport catalog (Terminal 2,
  Platforma CRA, runway 09/27, entrances/exits, check-in, security, customs, boarding, gates,
  belts, parking, control tower, cargo…) — see [docs/airport-zones.md](docs/airport-zones.md).
* **Report action** is a large full-width bar at the bottom of the crew and dispatcher screens — one tap, always reachable on a phone.
* **No duplicate tickets**: a second report of the same incident type at the same location (15 min) or with identical normalized words (30 min) returns the existing open ticket instead of creating a new one.
* **Alerts** go only to accounts whose department scope intersects the ticket's primary
  departments (e.g. a fuel leak alerts Earl Engineer + John Janitor). Android notifications are
  local (no cloud push): keep the phone connected and awake during the demo.
* **Transport:** one TLS listener for HTTPS + WSS; the app pins `assets/certs/ca.crt`. The
  Waterfox control room trusts the same CA through a dedicated profile.

---

## 5. Backend quick reference

| Method | Path | Purpose |
|---|---|---|
| POST | `/api/reports` | Create ticket (voice transcript / menu hint code) |
| POST | `/api/analyze` | Conversational turn: fields + missing + question |
| POST | `/api/transcribe` | Audio → text (local faster-whisper) |
| GET | `/api/tickets[?status=]`, `/api/tickets/{id}` | List / read |
| POST | `/api/tickets/{id}/confirm` · `/deny` · `/override` | Dispatcher actions |
| POST | `/api/tickets/{id}/join` · `/vote` | Crew join / resolve vote (quorum 2) |
| POST | `/api/dev/reset` | Clear the in-memory store |
| POST | `/api/tickets/clear-history` | Admin: permanently clears resolved/denied tickets |
| GET | `/api/occurrences` | Source-backed incident catalog; `?code=` / `?category=` filters |
| GET | `/api/health`, `/api/taxonomy`, `/healthz`, `/ca.crt` | Diagnostics / public checks |
| WS | `/ws?token=` | `hello`, `ticket.created/updated/resolved`, `ping` |

Field-level contract: [CONTRACTS.md](CONTRACTS.md). Wire parity is enforced by
`scripts/check_wire_parity.py`.

---

## 6. DevTools & looks

Login → **wrench icon** (top-right): preview all six time-of-day looks (Zori / Dimineață /
Amiază / După-amiază / Apus / Noapte), live backend health (Ollama/STT/WSS/tickets), simulate a
report, reset the store, inspect account scopes.

Deterministic build for photos: `--dart-define=SKY_PERIOD=night` (also `dawn`, `morning`,
`midday`, `afternoon`, `sunset`).

---

## 7. Gates

```powershell
.\scripts\verify_all.ps1 -Live     # analyze + tests + parity + taxonomy + smoke + live
```

Individual commands and troubleshooting are in [docs/laptop-setup.md](docs/laptop-setup.md) and
[docs/phone-testing.md](docs/phone-testing.md). The curated demo screenshots live **outside the
repo** at `D:\Hackathon\Screenshots`.

---

## 8. Documentation

Full index: **[docs/README.md](docs/README.md)**. Most useful now:

| Doc | Contents |
|---|---|
| [docs/demo-script.md](docs/demo-script.md) | 3-minute rehearsal script + fallbacks |
| [docs/airport-zones.md](docs/airport-zones.md) | Craiova zone catalog (map sources) |
| [docs/design-tokens.md](docs/design-tokens.md) | Design system / theme tokens |
| [docs/reporter.md](docs/reporter.md) | Reporter flow, local brain, STT integration |
| [docs/team-timeline.md](docs/team-timeline.md) | How the team worked: timeline + per-person showcase |
| [CONTRACTS.md](CONTRACTS.md) | Frozen Dart ↔ FastAPI wire contracts |
| [scripts/README.md](scripts/README.md) | Every automation script, what it does |


