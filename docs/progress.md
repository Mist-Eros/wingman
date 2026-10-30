# Build progress — live checklist

Updated: 2026-10-30 (H0 session). Tick items as they land.

## Done ✅

| Item | Evidence |
|---|---|
| Repo created at `D:\Hackathon\Wingman` (git, 2 commits) | `git log --oneline` |
| Toolchain installed (Git 2.56, Python 3.12.10, OpenSSL 4.1, Flutter 3.47.9 / Dart 3.13.7) | `flutter --version` |
| Flutter project scaffolded (android/, ios/, lib/, test/) | `flutter analyze` |
| TLS certs generated: **Wingman Local CA**, SAN `127.0.0.1`, `192.168.0.170`, `wingman.local`, `localhost` | `backend/certs/`, `assets/certs/ca.crt` |
| Backend venv + deps installed | `backend\.venv` (33 MB) |
| Backend running with TLS on 8443 | `https://192.168.0.170:8443/healthz` |
| **Backend smoke test 37/37 with strict CA validation** | `python scripts\smoke_test.py --ca backend\certs\ca.crt` |
| Dart compiles: **flutter analyze → No issues found** | `flutter analyze` |
| Core contract tests **13/13** | `flutter test` |
| **Live Dart client ↔ TLS backend test 6/6** (CA pinning, WSS, full flow) | `$env:WINGMAN_LIVE='1'; flutter test test\live_backend_test.dart` |
| Firewall rule "Wingman 8443" (inbound, any profile, TCP 8443) | `Get-NetFirewallRule` |
| Wi-Fi network profile set to **Private** | `Get-NetConnectionProfile` |
| Taxonomy authored (14 types / 4 categories, OP-OTHER catch-all) + backend JSON generated | `lib/core/incidents/taxonomy.dart`, `backend/taxonomy.json` |
| Contracts + docs + demo runbook written | `CONTRACTS.md`, `docs/` |
| **Conversational `/analyze` contract** (`fields` + `missing` + `question`, max 3 questions, dispatcher cap) | smoke 50/50 · live Dart 7/7 |
| `compileSdk = 37` pinned in `android/app/build.gradle.kts` (permission_handler fix) | F1 request applied |
| Teammate distribution zip | `D:\Hackathon\Wingman-repo.zip` (bundle: `D:\Hackathon\Wingman.bundle`) |
| **GitHub repo (private) `Mist-Eros/wingman`**, full history pushed | `git log --oneline`, `gh repo view` |
| **Demo APKs built**: TLS release, emergency HTTP release, TLS debug | `D:\Hackathon\dist\` (47.5 / 47.5 / 170 MB) |
| **Voice → text**: `POST /api/transcribe` (local faster-whisper `small` int8) + Dart `api.transcribe` | smoke 56/56 · live Dart 7/7 · `docs/whisper-contract.md` |
| Hotspot fallback for phone testing (guest Wi-Fi isolates clients) | SSID `DESKTOP-ET39230 5531`, laptop IP `192.168.137.1`, `scripts/hotspot_on.ps1` |
| **Local LLM live**: Ollama 0.40.13 + Qwen2.5-1.5B-Instruct Q4_K_M (built from official HF GGUF, official Qwen chat template) | `/api/analyze` → `ai_source: "ollama"`, **0.3–0.6 s/report on the RTX 4060** |
| **AI classification matrix 5/5** (smoke→SF-FIRE, bandă→MT-BELT, bagaj→SC-BAG, suspect→SC-BEHAV, coadă→OP-QUEUE) | `backend/app/ai.py` prompt triggers + deterministic keyword guards |
| **Voice → text verified with real speech** (Windows TTS → `/api/transcribe` → exact sentence) | `scripts/check_stt.ps1` (200, ~4.8 s for 4.2 s audio, CPU int8) |
| **All gates green with live AI**: smoke 56/56, live Dart 7/7, `flutter analyze` clean, 18 offline tests | `scripts/smoke_test.py`, `flutter test` |
| **First real phone end-to-end**: Samsung S24 Ultra (Android 16) — release APK, pinned TLS, WSS connected, live ticket appeared instantly | screenshot/bring-up on 2026-10-30; `adb -s RFCX60EYMEY` |
| **Crew feature merged & verified on phone**: Echipaj list, Preia (join), Rezolvat (vote), 2/2 quorum -> resolved live over WSS | lib/features/crew/, phone RFCX60EYMEY |
| **Reporter feature merged & verified on phone** (typed path): „fum lângă poarta 12" → SF-FIRE critical 95%, follow-up question, confirmation, `POST /api/reports 201`, departments Pompieri/Securitate | `lib/features/reporter/`, 141 tests, smoke 58/58 |
| **Server mirrors the reporter urgency brain**: fire/toxic/life → critical, size/flags escalate, medical → OP-OTHER triage + `Department.medical` standby | `backend/app/ai.py::apply_transcript_urgency`, taxonomy v1 re-synced |
| Kotlin incremental cache fix after interrupted build | `android/gradle.properties` (+ clean rebuild: 1.2 min) |
| Android bring-up fixes: release INTERNET permission, targetSdk 35 for Android 16 LAN policy, build-script dart-define bug, `kApiBase` sanitizer | `android/app/src/main/AndroidManifest.xml`, `build.gradle.kts`, `lib/main.dart` |
| **Design system v1** (Material 3 navy airport-ops theme, semantic urgency/status palette, component themes, spacing/radius scale) | `lib/core/theme/wingman_theme.dart`, `docs/design-tokens.md` |
| **Design applied**: role picker (brand mark + status pill), reporter (navy mic), crew (primary „Preia"), dispatcher appbar restyle | screenshots on phone RFCX60EYMEY |
| **Bug fixes verified on phone**: dispatcher live-by-default, compact appbar, SafeArea for bottom actions (Confirmă/Respinge/Reclasifică reachable), Reclasifică → backend SF-FOD `decided_by` set | `lib/features/dispatcher/dispatcher_screen.dart`, `backend` log `POST /override 200` |
| **Session persistence**: saved session + secure token store; re-picking the same role keeps the crew/dispatcher id, so a joined ticket stays joined after app restart | `lib/core/auth/session_store.dart`, `lib/main.dart` |
| Friendly error messages (no raw SocketException on screen) + pluralization fixes | `lib/core/state/ticket_board.dart`, `lib/main.dart`, crew card |
| Rehearsal assets: `TEAM.md`, `docs/demo-script.md` (3-min flow + fallbacks), seed script verified | repo root, `backend/seed_demo.py` |
| **Hardcoded demo accounts with encrypted credentials**: admin/engineer/janitor/reporter, salted SHA-256 passwords, login sheet with hash validation, persisted identity | `lib/core/auth/demo_accounts.dart`, `lib/features/auth/login_screen.dart`, `test/demo_accounts_test.dart` |
| **Department-scoped alerts**: janitor sees only terminal incidents, engineer only maintenance/IT/baggage/airside, admin sees everything | `Session.seesDepartments` + crew primary-department filter; verified on phone (John Janitor → only SF-SPILL) |
| **Aerospace design**: animated sky gradient + drifting clouds + plane silhouette login, account cards with scope/password, mobile-friendly layout | `lib/core/widgets/sky_background.dart`, login screen |
| **Back button fixed**: role screens are pushed over login, Android back returns to the account chooser instead of exiting | `lib/main.dart` (`pushNamed`, `popUntil`) — verified on device |
| **Desktop control room (real-time)**: Flutter web dashboard in Edge — WSS live queue, urgency counters, departments, Confirmă/Respinge/Reclasifică | `lib/web_dashboard_main.dart`, `scripts/serve_dashboard.ps1` (no Visual Studio needed) |
| **Voice path verified end-to-end**: real spoken WAV fixture → `ApiClient.transcribe` over pinned TLS → local Whisper → `/api/analyze` → `SF-FIRE` | `test/fixtures/spoken_report.wav`, live test in `test/live_backend_test.dart` (**live 8/8**) |
| **Full gate run**: `scripts\verify_all.ps1 -Live` → **ALL GATES PASSED** (analyze clean, 146 app tests, live 8/8, smoke 59/59 strict TLS, wire parity, taxonomy sync) | verify_all output |
| **Demo APKs refreshed** (TLS + emergency HTTP, 51.1 MB each) against `192.168.0.170`; TLS build installed on the S24 and connected | `D:\Hackathon\dist\wingman-tls-release.apk`, `wingman-insecure-release.apk` |
| **Time-of-day skies**: six adaptive looks (Zori / Dimineață / Amiază / După-amiază / Apus / Noapte) chosen from the clock, stars + crescent moon at night, solid-white clouds, `--dart-define=SKY_PERIOD=…` for deterministic demo builds | `lib/core/widgets/sky_background.dart`, `test/sky_period_test.dart` |
| **DevTools screen**: wrench icon on login → preview all six looks, live server health (Ollama/STT/WSS/tickets), force a 5-second override ticket, reset store, account-scope matrix | `lib/features/dev/dev_tools_screen.dart` |
| **Desktop control room in Waterfox**: zero-dependency HTML dashboard (no CanvasKit/WebGL), trusted via private CA + dedicated Waterfox profile, opened from disk; `-Flutter` variant for Chromium | `scripts/serve_dashboard.ps1`, `scripts/dashboard/` |
| **Progress gallery**: 49 screenshots organised into `Hackathon\ProgressPics\Steep_01…09` (per-milestone folders + README) | `D:\Hackathon\ProgressPics\` |
| **Department-scoped notifications**: high-importance local notifications on the phone; a ticket alerts only accounts whose scope intersects its primary departments. Verified on-device: fuel/spill (maintenance+terminal) alerted the janitor, security-only bag did not | `lib/core/notifications/ticket_notifier.dart`, `test/notifications_test.dart` (4 tests) |
| **Reporting from anywhere**: crew + dispatcher app bars get a Raportează action; the PC Waterfox dashboard gets a report form (N / Ctrl+Enter) with location fields; verified admin report on PC → live dashboard ticket → phone notification | `scripts/dashboard/index.html`, dispatcher/crew screens |
| **S24 Ultra fit**: compact login (all 4 accounts + resume card fit), shortened reporter title, notification test on 1080×2340 | screenshots `D:\Hackathon\ProgressPics\Steep_10_Reporting_Notifications` |
| **Plane silhouette** redrawn as a real top-down airliner (fuselage, swept wings, tailplane, engines); crescent moon via transparent cutout | `lib/core/widgets/sky_background.dart` |
| **Conversational AI fix — no redundant questions**: person-harm phrasings („un copil a luat foc", „pasagerul a leșinat") now imply `people_at_risk=true`, and an already-given location is never asked again. `Un copil a luat foc la poarta 4` → SF-FIRE/critical/Poarta 4, **ready immediately, no questions**. Smoke **65/65** | `backend/app/ai.py`, `scripts/smoke_test.py` [10c], parity fix for `force_override` |

## In progress ⏳

| Item | Owner | Notes |
|---|---|---|
| Demo rehearsal on 2-3 phones + desktop | **user + Lead** | sign in as Rita/Earl/John/Andy per `docs/demo-script.md`, run the 3-min flow, time it |
| Physical microphone check (human step) | **user** | hold the mic on Rita's reporter screen and speak; the code path is verified by the live WAV test, this only confirms the device mic |
| Desktop dashboard polish | Lead | add ticket age/live feed highlights if time permits |
| Location gate (on-airport-only) | Lead | designed in `docs/backlog.md`; after the demo flow is stable |

## Next

1. Rehearse the 3-minute script with the new accounts (Rita reporter → Andy admin desktop →
   Earl engineer → John janitor) and the desktop control room open on the laptop.
2. Real-mic test on the reporter account.
3. Optional: project the dashboard on the big screen while phones act (F11 fullscreen in Edge).
4. iOS stays **cloud Mac later** (Apple Developer account needed for device installs).

## Next (H0–H4 remaining)

1. **Phone test (user, 2 min):** Safari/Chrome on one Android → `https://192.168.0.170:8443/`.
   - Page loads (after accepting the cert warning) → network path works.
   - Timeout → guest Wi-Fi client isolation → switch phones + laptop to the laptop hotspot and
     re-run `.\scripts\gen_certs.ps1 -Force` (documented in `docs/laptop-setup.md`).
2. **Plug one Android phone via USB, enable Developer options → USB debugging.**
3. Build + install: `.\scripts\build_demo_apks.ps1` (produces TLS + emergency HTTP APKs).
4. Run the app: role picker → reporter → report → dispatcher/crew screens (stubs for now).
5. Send `Wingman-repo.zip` (or a git remote) to F1/F2/F3 with `CONTRACTS.md` §1–§7.
6. Verify the AI path: `python scripts\smoke_test.py --ca backend\certs\ca.crt` after the model
   pull finishes — reports should show `ai_source: ollama`, not `fallback`.
7. iOS (decision: **cloud Mac later**): needs an Apple Developer account for device installs;
   keep it out of the critical path until the H24 contract freeze.

## Demo-riskiest item right now

`HACKATHON-GUEST` is a guest SSID. If phones cannot reach the laptop, the whole live demo
depends on the hotspot fallback — test it **today**, not at H36.
