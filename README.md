# Wingman — 48h hackathon starter

**Wingman** — the airport's extra pair of eyes. Flutter app (Android + iOS) for airport
incident reporting: staff report by **voice or a button menu**, a **local Ollama model**
classifies the report into a **closed 14-type taxonomy**, the server assigns **urgency +
departments** and broadcasts over **WSS** to a dispatcher dashboard and crew phones. Low
confidence sends the ticket to the dispatcher for a **5-second confirm/deny/reclassify
window**; crews **join** and **vote to resolve**. Transport is TLS 1.3 with a self-signed CA
pinned in the app; tokens go to flutter_secure_storage; nothing is stored at rest outside the
in-memory demo store.

**Name / identifiers:** display name **Wingman** · suggested bundle id `com.wingman.app` ·
suggested project scaffold `flutter create --org com.wingman --project-name wingman` · set
`android:label="Wingman"` in `AndroidManifest.xml` and `CFBundleDisplayName = Wingman` in
`ios/Runner/Info.plist` · the demo CA is called **"Wingman Local CA"**.

This folder is a **working skeleton**, not a finished product: `lib/core/`, `lib/main.dart` and
`backend/` are real and tested; the three `lib/features/*` folders are **stubs owned by the
feature teammates** (see [CONTRACTS.md](CONTRACTS.md)).

---

## 1. What is in the box

| Path | Owner | What it is |
|---|---|---|
| `lib/core/incidents/taxonomy.dart` | Lead | **Single source of truth**: enums + the 14 `IncidentType`s + validation |
| `lib/core/models/ticket.dart` | Lead | `Ticket`, statuses, `ReportDraft`, location, JSON mapping |
| `lib/core/api/api_client.dart` | Lead | REST + auto-reconnecting WSS client (zero packages, `dart:io`) |
| `lib/core/state/ticket_board.dart` | Lead | Shared live ticket list (snapshot + WSS merge, sorting, actions) |
| `lib/core/core_scope.dart` | Lead | DI: `api`, `board`, `session`, `onSignOut` for every screen |
| `lib/core/models/session.dart` | Lead | Roles (`reporter`/`dispatcher`/`crew`) + demo session |
| `lib/core/auth/*` | Lead | `TokenStore`; optional flutter_secure_storage implementation |
| `lib/main.dart` | Lead | Role picker + role-based routes (only integration point) |
| `lib/features/reporter/` | Friend 1 | **STUB** — conversational report flow |
| `lib/features/dispatcher/` | Friend 2 | **STUB** — dashboard cards + confirm/deny/override |
| `lib/features/crew/` | Friend 3 | **STUB** — dispatch notification, join, resolve vote |
| `backend/app/` | Lead | FastAPI: `/api/reports`, `/api/analyze`, WSS hub, in-memory store, 5 s override timer, vote quorum |
| `backend/app/ai.py` | Lead | Ollama `/api/chat` call + JSON validation + deterministic keyword fallback |
| `backend/taxonomy.json` | generated | Backend mirror of the Dart taxonomy (do not hand-edit) |
| `scripts/gen_certs.ps1` | Lead | CA + server cert with multi-IP SAN, copies CA into the app assets |
| `scripts/smoke_test.py` | Lead | 37-check end-to-end gate (auth, WSS, override timer, votes, wire keys) |
| `scripts/sync_taxonomy.py` | Lead | Regenerates/verifies `backend/taxonomy.json` from the Dart file |
| `scripts/preflight.ps1` | Lead | Pre-demo laptop/network/Ollama/TLS checks |
| `tool/emit_taxonomy.dart` | Lead | Same generator, pure Dart |
| `docs/` | Lead | 48h timeline, demo risks, cert / phone runbook |

---

## 2. Architecture

```
 reporter phone (voice / menu)                dispatcher dashboard / tablet
        │  POST /api/reports                        ▲
        ▼                                           │ WSS ticket.*
 ┌────────────────────────────┐   ┌─────────────────┴──────────────┐
 │ FastAPI on laptop :8443    │   │  in-memory TicketStore          │
 │  · Pydantic validation     │──▶│  · status machine               │
 │  · Ollama classify (JSON)  │   │  · 5 s override timer           │
 │  · closed-taxonomy check   │   │  · crew join / vote quorum      │
 └──────────────┬─────────────┘   └─────────────────┬──────────────┘
                │ GET /api/analyze (debug)          │
                ▼                                   ▼
        Ollama 127.0.0.1:11434            crew phones (WSS, join, vote)
        qwen2.5:7b / llama3.1:8b

TLS: private CA (scripts/gen_certs.ps1) → CA bundled in app + installed on phones
```

One port, one TLS listener: HTTPS REST **and** WSS (`wss://<laptop>:8443/ws`). The backend
also serves `/`, `/healthz` and `/ca.crt` **without auth**, so a phone browser can prove the
certificate is installed correctly.

---

## 3. Hour-0 setup on the laptop (Windows)

```powershell
# toolchain (skip what you already have)
winget install --id Git.Git -e
winget install --id Python.Python.3.12 -e
winget install --id ShiningLight.OpenSSL.Light -e
winget install --id Flutter.Flutter -e          # or use your existing Flutter install

# Ollama (once): install, then pull the chosen model
winget install --id Ollama.Ollama -e
ollama pull qwen2.5:1.5b
# alternative: ollama pull llama3.1:8b   → set $env:OLLAMA_MODEL='llama3.1:8b'
# If the Ollama registry stalls on the venue network (it did for us), build the
# same model from the official HuggingFace GGUF instead:
#   .\scripts\prepare_ollama_model.ps1
```

Open a **new** terminal after installs, then:

```powershell
# 1) certificates: creates backend/certs/* and assets/certs/ca.crt
.\scripts\gen_certs.ps1 -Force

# 2) firewall once (elevated PowerShell)
New-NetFirewallRule -DisplayName "Wingman 8443" -Direction Inbound -Protocol TCP `
  -LocalPort 8443 -Action Allow -Profile Private

# 3) backend (installs Python deps on first run, prints phone URLs)
cd backend
.\run.ps1
#   later/again from anywhere:  cd backend; .\run.ps1
#   demo-only emergency:        .\run_insecure.ps1   (plain HTTP :8080)

# 4) in a second terminal — seed + prove the whole backend
cd ..
python backend\seed_demo.py
python scripts\smoke_test.py            # must print 37 passed · 0 failed

# 5) run the app on a phone (USB debugging; Android needs the Android SDK)
#    The Flutter project IS this repo (android/, ios/, lib/, test/ are generated)
cd D:\Hackathon\Wingman
flutter pub get
flutter analyze
flutter test
flutter run --dart-define=API_BASE=https://<LAPTOP_IP>:8443 --dart-define=API_TOKEN=demo-token

# 6) one-command gate before every merge
.\scripts\verify_all.ps1
```

Phone-side CA installation (2 iPhones + 2 Androids): **[docs/certs-and-phones.md](docs/certs-and-phones.md)**
— but note the app already pins the bundled CA, so the profile is mainly for
Safari/Chrome verification and system traffic.

---

## 4. How the app is wired

* **Roles**: `main.dart` shows a role picker, then routes to
  `/reporter`, `/dispatcher` or `/crew`. Feature screens get everything through `CoreScope`:

  ```dart
  final session = CoreScope.sessionOf(context);   // role, userId, displayName
  final board   = CoreScope.boardOf(context);     // live tickets (ChangeNotifier)
  final api     = CoreScope.apiOf(context);       // REST + WSS
  CoreScope.of(context).onSignOut();
  ```

* **Live data**: `TicketBoard` loads `GET /api/tickets` once and applies every WSS event.
  Wrap UI in `ListenableBuilder(listenable: CoreScope.boardOf(context), ...)`.
  Sorted: pending override → urgency → newest. Helpers: `pendingOverrides`,
  `activeTickets`, `forDepartment(Department.security)`, `confirm/deny/override/join/vote`.

* **Config is compile-time** (no runtime config screen on purpose):
  `--dart-define=API_BASE=...`, `--dart-define=API_TOKEN=...`,
  `--dart-define=DEV_INSECURE=true` (dev fallback only).

---

## 5. pubspec additions

`pubspec_additions.yaml` in the repo root has the snippets. Minimum for the app to build and
speak TLS:

```yaml
flutter:
  assets:
    - assets/certs/ca.crt
```

Optional, when their features land:
`flutter_secure_storage` (token persistence — see `lib/core/auth/secure_token_store.dart`) and
a speech-to-text package for the reporter voice flow (Friend 1's call; keep the recorded
transcript as the fallback path for the demo).

After `gen_certs.ps1` runs, **commit `assets/certs/ca.crt`** (public cert) but **never
`ca.key` / `server.key`** — see `.gitignore`.

---

## 6. Backend quick reference

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/api/reports` | Bearer | Create ticket (voice transcript or menu `hint_code`) |
| POST | `/api/analyze` | Bearer | Conversational turn: `fields` + `missing` + `question` (reporter flow) |
| POST | `/api/transcribe` | Bearer | Voice → text (local faster-whisper; base64 JSON) |
| GET | `/api/tickets[?status=]` | Bearer | List (newest first) |
| GET | `/api/tickets/{id}` | Bearer | One ticket |
| POST | `/api/tickets/{id}/confirm` | Bearer | Dispatcher confirms (ends the 5 s window) |
| POST | `/api/tickets/{id}/deny` | Bearer | Dispatcher rejects, with reason |
| POST | `/api/tickets/{id}/override` | Bearer | Reclassify to another taxonomy code |
| POST | `/api/tickets/{id}/join` | Bearer | Crew joins (dispatched → in_progress) |
| POST | `/api/tickets/{id}/vote` | Bearer | Approve resolution (quorum 2 by default) |
| POST | `/api/dev/reset` | Bearer | Clear store between rehearsals |
| GET | `/api/health`, `/api/taxonomy` | Bearer | Diagnostics / catalog |
| GET | `/healthz`, `/`, `/ca.crt` | public | Phone certificate verification |
| WS | `/ws?token=` | token | Broadcast: `hello`, `ticket.created`, `ticket.updated`, `ticket.resolved`, `ping` |

Full field-level contract (JSON keys, statuses, errors): **[CONTRACTS.md](CONTRACTS.md)**.

### Desktop control room (real-time ops view)

```powershell
.\scripts\serve_dashboard.ps1        # opens the live control room in Waterfox
.\scripts\serve_dashboard.ps1 -Flutter   # optional: CanvasKit build for Chromium/Edge
```

The default dashboard is a **zero-dependency HTML page** (`scripts/dashboard/`) opened from
disk (`file://`) in **Waterfox** with a dedicated demo profile. It talks to the same backend as
the phones: REST snapshot + **live WSS** events, urgency counters, ticket cards, department and
location details, and Confirmă / Respinge / Reclasifică actions. The script imports our private
CA into the current-user trust store and enables `security.enterprise_roots.enabled`, so
HTTPS/WSS are trusted without any ignore-certificate flags. `-Flutter` builds the optional
Flutter web variant (`lib/web_dashboard_main.dart`) and serves it over HTTP for Chromium.

**DevTools (in the app):** on the login screen tap the wrench icon (top-right) to preview all
six time-of-day looks (Zori / Dimineață / Amiază / După-amiază / Apus / Noapte), see live
backend health (Ollama, STT, WSS, tickets), trigger a forced 5-second override ticket, reset the
store, and inspect the demo-account scopes. The sky itself follows the phone clock; for a
deterministic build use `--dart-define=SKY_PERIOD=night` (`dawn`, `morning`, `midday`,
`afternoon`, `sunset`).

**Demo accounts** (hardcoded, passwords stored as salted SHA-256; scope decides alerts):
`admin/admin123` (everything), `engineer/engineer123` (maintenance/IT/baggage/airside),
`janitor/janitor123` (terminal only), `reporter/reporter123` (reports incidents).
Back from a role screen returns to the login screen (no more app exit).

---

## 7. Gates (run before every merge)

```powershell
.\scripts\verify_all.ps1                   # everything below in one command
```

```powershell
python scripts\sync_taxonomy.py            # taxonomy.dart ↔ backend/taxonomy.json
python scripts\check_wire_parity.py        # Dart JSON mapping ↔ FastAPI wire (offline)
flutter analyze
flutter test                               # core contract tests (taxonomy/wire/session)
$env:WINGMAN_LIVE="1"; flutter test test\live_backend_test.dart
                                           # LIVE: real Dart client ↔ TLS backend (REST+WSS)
python scripts\smoke_test.py --ca backend\certs\ca.crt   # backend must pass 37/37
```

One command for all of it: `.\scripts\verify_all.ps1 -Live` (backend must be running).

The smoke test also asserts that the backend ticket JSON keys **exactly** match what
`Ticket.fromJson` reads — that is the single most effective integration gate.

---

## 8. Demo flow (6 minutes)

1. Pick **Raportor** on iPhone 1 → speak the smoke/fire scenario or tap SF-FIRE in the menu.
2. Dispatcher screen (tablet/iPhone 2) shows the new card; a forced low-confidence report
   (voice) opens the **5-second countdown** → confirm or reclassify.
3. Crew phones get the dispatch → **Preia** → **Rezolvat** votes; card flips to resolved.
4. Close with the architecture slide: closed taxonomy prevents hallucinated codes;
   TLS + pinned CA; 5 s human-in-the-loop; deterministic fallback if the AI fails.

Rehearsal runbook and fallbacks: **[docs/demo-risks.md](docs/demo-risks.md)**.
Schedule: **[docs/48h-timeline.md](docs/48h-timeline.md)**. Team rules:
**[CONTRACTS.md](CONTRACTS.md)**.

---

## 9. Troubleshooting (top hits)

| Symptom | Fix |
|---|---|
| App: `TLS handshake failed` | IP not in cert SAN, or CA asset missing. Re-run `gen_certs.ps1 -Force`, `flutter pub get`, rebuild. |
| App: `Cannot reach https://...` | Phone on different Wi-Fi / AP isolation / Windows firewall on Public profile / backend not running. |
| Dispatcher empty | `python backend\seed_demo.py`; check WSS banner on the role screen. |
| `ollama` warnings in `/api/health` | `ollama serve`, then `ollama pull <model>`; backend auto-warms on startup. |
| Port 8443 in use | Stop the old uvicorn, or change port in `backend\run.ps1` **and** the app's `API_BASE`. |
| Python is the Microsoft Store stub | Install real Python 3.12 (`winget`), open a new terminal, rerun `run.ps1`. |
| Phone-side CA profile installs but the app still fails | Expected on Android 7+ (apps don't trust user CAs), and possible on iOS. The app pins the bundled CA instead — rebuild after `gen_certs.ps1`, and make sure `assets/certs/ca.crt` exists and is declared in `pubspec.yaml`. |
| `flutter run` fails: unable to find `assets/certs/ca.crt` | Run `.\scripts\gen_certs.ps1 -Force` first (it creates the asset), then `flutter pub get`. |
| Manual PowerShell `POST /api/reports` returns 400/422 with Romanian text | Windows PowerShell 5.1 mangles UTF-8 bodies and quotes. Use `python backend\seed_demo.py`, `scripts\smoke_test.py`, or `curl.exe --data-binary "@body.json"`. The API accepts UTF-8 JSON (verified with the smoke test). |
