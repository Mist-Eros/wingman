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
| **Progress gallery**: 18 curated screenshots in `D:\Hackathon\Screenshots` (categorised folders + README); duplicates/failed experiments deleted | `D:\Hackathon\Screenshots\` |
| **Demo roles expanded**: reporter account deleted; **Fred Firefighter** (`firefighter123`, fire/rescue) and **Gina Guard** (`guard123`, security) added; login shows 5 accounts; alerts verified per scope (Guard sees SF-FIRE + SC-BAG, Firefighter sees SF-FIRE) | `lib/core/auth/demo_accounts.dart`, `test/demo_accounts_test.dart` |
| **AI takes all available info — app side fixed**: the reporter's local conversation brain no longer invents "detail" questions when the server says the report is complete. On-device: typing „o femeie a luat foc la poarta 2" goes **straight to verification** (SF-FIRE, Poarta 2, Persoane în pericol: Da, Critică, 95%) with **zero questions** | `lib/features/reporter/brain/conversation_brain.dart`, `test/conversation_brain_test.dart` (6 tests) |
| **Admin screen mobile layout fixed**: phone dispatcher got a slim LIVE/urgency row, no big banners/department strip; a full ticket is now visible and the queue scrolls | `lib/features/dispatcher/dispatcher_screen.dart` (`_CompactUrgencyRow`) |
| **PC report form** rebuilt: no dropdowns — free-text terminal + zone inputs, bigger textarea, quick-fill chips (Scurgere / Bagaj / Persoană / Incendiu), N + Ctrl+Enter shortcuts | `scripts/dashboard/index.html` |
| **Department-scoped notifications**: high-importance local notifications on the phone; a ticket alerts only accounts whose scope intersects its primary departments. Verified on-device: fuel/spill (maintenance+terminal) alerted the janitor, security-only bag did not | `lib/core/notifications/ticket_notifier.dart`, `test/notifications_test.dart` (4 tests) |
| **Reporting from anywhere**: crew + dispatcher app bars get a Raportează action; the PC Waterfox dashboard gets a report form (N / Ctrl+Enter) with location fields; verified admin report on PC → live dashboard ticket → phone notification | `scripts/dashboard/index.html`, dispatcher/crew screens |
| **S24 Ultra fit**: compact login (all 5 accounts + resume card fit), shortened reporter title, notification test on 1080×2340 | screenshots `D:\Hackathon\Screenshots\01_Login_and_Roles` |
| **Plane silhouette** redrawn as a real top-down airliner (fuselage, swept wings, tailplane, engines); crescent moon via transparent cutout | `lib/core/widgets/sky_background.dart` |
| **Conversational AI fix — no redundant questions**: person-harm phrasings („un copil a luat foc", „pasagerul a leșinat") now imply `people_at_risk=true`, and an already-given location is never asked again. `Un copil a luat foc la poarta 4` → SF-FIRE/critical/Poarta 4, **ready immediately, no questions**. Smoke **65/65** | `backend/app/ai.py`, `scripts/smoke_test.py` [10c], parity fix for `force_override` |
| **Dispatch-first policy — no blocking questions**: the “is anyone in danger?” question is removed entirely; high/critical reports are routed to the right departments immediately and the dispatcher confirms/denies in the 5-second window. Sector locations are extracted (`sectorul 2`, `terminal 7`). Verified on-device: `o pisica a luat foc la sector 2 terminal 7` → SF-FIRE/critical/Terminal 7 → **straight to verification, zero questions**. Smoke **70/70** | `backend/app/ai.py`, `lib/features/reporter/brain/conversation_brain.dart`, `scripts/smoke_test.py` [10c] |
| **Craiova airport zone catalog**: locations match the real map — Terminal 2, Platforma CRA, runway 09/27 (OSM data), plus Terminal 1 / Sosiri / Plecări, **Intrarea & Ieșirea principală**, Check-in, Control securitate, Vamă, Zona de îmbarcare, Poarta / Banda / Stand N, Parcare (P1/P2, scurtă/lungă, taxi), Turn de control, Cargo, Hangar. On-device: `a luat foc un calculator la intrare` → **Intrarea principală, no questions, dispatched**. PC dashboard now uses a single “Zonă / locație” field (no dropdowns, no quick chips); the server extracts the zone from the text when left empty. Smoke **90/90** | `backend/app/ai.py` (`_LOCATION_ZONES`), `docs/airport-zones.md`, `scripts/dashboard/index.html` |

## In progress ⏳

| Item | Owner | Notes |
|---|---|---|
| Demo rehearsal on 2-3 phones + desktop | **user + Lead** | sign in as **Fred/Gina/Earl/John/Andy** per `docs/demo-script.md`, run the 3-min flow, time it |
| Physical microphone check (human step) | **user** | hold the mic on a friend's report screen and speak; the code path is verified by the live WAV test + typed device test |
| Desktop dashboard polish | Lead | add ticket age/live feed highlights if time permits |
| Location gate (on-airport-only) | Lead | designed in `docs/backlog.md`; after the demo flow is stable |

## Next

1. Rehearse the 3-minute script: PC admin report (N → type → Ctrl+Enter) → phone notification →
   crew Preia/Rezolvat; switch phones between Earl/John/Fred/Gina to show scoped alerts.
2. Real-mic test on any report screen (voice button) — the typed path is already verified.
3. Optional: project the Waterfox control room on the big screen (F11).
4. iOS stays **cloud Mac later** (Apple Developer account needed for device installs).

---

## 2026-10-31 — demo polish (round 2)

| Change | Where | Evidence |
|---|---|---|
| **5-second override window removed end-to-end**: reports dispatch immediately, no `pending_override`, no deadline, no countdown UI, no bell badge, no DevTools simulation. Dispatcher can still deny/reclassify. | `backend/app/store.py`, `backend/app/main.py`, `lib/features/dispatcher/**`, `lib/features/dev/dev_tools_screen.dart`, `scripts/dashboard/index.html` | backend smoke **88/88**; app tests **160**; live report lands directly as `dispatched` |
| **Admin queue hides closed/denied tickets** (clutter removed); counts/queue are active-only. | `lib/features/dispatcher/dispatcher_filters.dart`, `scripts/dashboard/index.html` | denied MT-BELT disappeared from queue and counters; 6 open tickets shown, denied one absent |
| **Low-priority cards are white** instead of blue. | `lib/features/dispatcher/urgency_style.dart` | verified on the S24: OP-OTHER low card is white |
| **"Confidence" now means likelihood of happening at Craiova airport** (type + named zone + urgency heuristic), shown in the reporter card, dispatcher cards/detail, Waterfox control room and optional Flutter web dashboard. | `lib/core/incidents/likelihood.dart`, models' `craiovaLikelihood`, `lib/features/dispatcher/**`, `scripts/dashboard/index.html` | OP-OTHER 63%, SF-FIRE 98%, SC-BAG 94% in the control room |
| **Compact dispatcher top bar fixed** — pending bell removed, no overlap with the back/route controls. | `lib/features/dispatcher/dispatcher_screen.dart` | clean phone screenshot: WSS pill · Demo/Live · overflow · logout |
| **Dashboard launcher repaired** (lost newline + out-of-order profile/CA setup); supports `-ApiBase`. | `scripts/serve_dashboard.ps1` | Waterfox control room opens and connects live |
| **Live-demo over USB** while the venue Wi-Fi isolates clients: `adb reverse tcp:8443 tcp:8443` + APK built for `https://127.0.0.1:8443` (cert already covers 127.0.0.1). | `scripts/serve_dashboard.ps1`, APK build | desktop report at 10:56 → phone queue count updated to 7 via WSS |

---

## 2026-10-31 — occurrence catalog (official reporting framework)

| Change | Where | Evidence |
|---|---|---|
| **Source-backed incident database** with **59 possible airport incidents** grouped in **8 operational domains** (movement/runway, terminal, services, ground handling, aircraft, security, dangerous goods, human factors). Each entry has RO/EN name, description, EU reference, ASRS event type, mandatory-reporting flag, aliases and a concrete example. | `backend/app/data/occurrences.json` | JSON validates at backend startup; **55/59** marked mandatory in the EU framework |
| **Catalog API** for the app/UI/AI: full catalog, filters by operational code or domain, single-entry lookup. | `backend/app/main.py` (`/api/occurrences`), `backend/app/occurrences.py` | smoke checks: 59 entries, unique IDs, valid codes, sources, filtering, lookup |
| **Fallback classifier uses the catalog**: when Ollama is unavailable and base keywords are weak, catalog aliases refine the code (e.g. drone → SC-ACCESS, unruly passenger → SC-BEHAV, dangerous goods → SC-ITEM). | `backend/app/ai.py` | direct fallback checks; normal AI path unchanged |
| **Generated documentation** with source links, mapping to Wingman's 14 codes and per-domain tables. | `docs/occurrence-catalog.md`, `scripts/render_occurrence_catalog.py` | regenerated from JSON; docs index updated |
| Gates after catalog: app **160 tests**, backend smoke **96/96**, wire parity OK. | repo | analyze clean + smoke pass |

---

## 2026-10-31 — bottom report bar + refreshed screenshots + equal team cards

| Change | Where | Evidence |
|---|---|---|
| **Large bottom report bar** on crew and dispatcher: full-width 60 px button, SafeArea, max-width 760 on desktop; app-bar report icons removed. | `lib/core/widgets/report_action_bar.dart`, `lib/features/crew/crew_screen.dart`, `lib/features/dispatcher/dispatcher_screen.dart` | verified on S24: bar visible on queue, crew and reporter return; content no longer covered |
| **Fresh screenshot set** — login, reporter (voice/menu/typed/verification), dispatcher (queue/low/demo), crew (queue/joined), notification shade, Waterfox control room + modal, DevTools. Old design folders removed. | `D:\Hackathon\Screenshots\Wingman\`, `Screenshots/README.md` | 15 new real captures |
| **Equal team cards** — same 1600×1450 template, 3 screenshots, 3 stats, 4 bullets each; 2×2 grid. | `D:\Hackathon\Screenshots\Team\` | `furtuna-lead.png`, `cutulescu-reporter.png`, `fita-dispatcher.png`, `lica-crew.png`, `team-grid.png` |

---

## 2026-10-31 — logo + admin history

| Change | Where | Evidence |
|---|---|---|
| **Real app logo** used once (login header) and as Android launcher icon; transparent banner, no duplicated wordmark; single branding asset. | `assets/branding/`, `pubspec.yaml`, `lib/features/auth/login_screen.dart`, `android/.../mipmap-*/ic_launcher.png` | S24 login + launcher; APK rebuilt |
| **Admin Istoric tab** with every resolved/denied ticket and **Golește istoricul** (confirm dialog, backend endpoint, board refresh). | `lib/features/dispatcher/dispatcher_screen.dart`, `lib/core/api/api_client.dart`, `lib/core/state/ticket_board.dart`, `backend/app/main.py`, `backend/app/store.py` | 2 history tickets shown, cleared → 0; smoke 99/99 |
| Screenshots updated with logo, tabs, history and cleared state; equal cards regenerated. | `D:\Hackathon\Screenshots\` | `Wingman/03_Dispatcher/04_history.png`, `05_history_cleared.png`, new `team-grid.png` |

---

## 2026-10-31 — logo cleanup + duplicate-ticket guard

| Change | Where | Evidence |
|---|---|---|
| Logo removed from app UI; it lives **only as the launcher/app icon**. Login restored to the previous Wingman header; branding assets no longer bundled. | `lib/features/auth/login_screen.dart`, `pubspec.yaml`, `android/.../mipmap-*` | S24 login no longer shows the logo; launcher icon unchanged |
| **Duplicate tickets blocked server-side**: same open incident type + same location within 15 min, or identical normalized transcript within 30 min, returns the existing ticket with `duplicate: true` — no new ticket, no duplicate WSS event. | `backend/app/store.py` (`find_duplicate`), `backend/app/main.py` | smoke 101/101: second MT-BELT report keeps the same id and only one open MT-BELT |
| Screenshots/cards refreshed after logo removal; history screenshots included. | `D:\Hackathon\Screenshots\` | new login capture, updated `team-grid.png` |

---

## 2026-10-31 — urgency-based crew quorum

| Change | Where | Evidence |
|---|---|---|
| Crew resolution quorum now depends on danger: **low/medium = 1 vote**, **high/critical = 2 votes** (was always 2). | `backend/app/store.py` (`QUORUM_BY_URGENCY`), `lib/features/dispatcher/demo_tickets.dart` | smoke: low OP-OTHER resolves with 1 vote; critical SF-FIRE still needs 2; 103/103 |
| DevTools shows the mapping; docs updated. | `lib/features/dev/dev_tools_screen.dart`, README/CONTRACTS | health exposes `resolve_quorum_by_urgency` |

---

## 2026-10-31 — 8×8×8 full-screen incident menu

| Change | Where | Evidence |
|---|---|---|
| **8 categories × 8 subcategories × 8 problems = 512** catalog, each mapped to one of the 14 operational codes and carrying exact label + location. | `lib/features/reporter/menu/incident_menu_data.dart`, generator | data test: 8/8/8, 512 unique IDs, valid codes |
| Menu redesigned as a **full-screen 4 rows × 2 columns grid** at all 3 levels; **3 taps** (category → subcategory → problem) submit the report with the exact problem label/location. | `lib/features/reporter/type_picker_page.dart`, `reporter_screen.dart`, `reporter_controller.dart` | verified on S24; ticket transcript “Bagaj suspect — Terminal”, SC-BAG |
| New menu screenshots and equal cards. | `D:\Hackathon\Screenshots\Wingman\02_Reporter\06–09_*`, `Team/team-grid.png` | 4 captures |

---

## 2026-10-31 — PC dashboard rebuilt as admin view

| Change | Where | Evidence |
|---|---|---|
| Desktop control room restyled to match the phone admin view: light theme, urgency-tinted queue cards, stats, **Coadă / Istoric tabs**, history cards and **Golește istoricul**, report button, detail pane. | `scripts/dashboard/index.html` | Waterfox screenshots: queue + history + light report modal; JS syntax check OK |
| Backend clear-history endpoint drives the dashboard too. | `POST /api/tickets/clear-history` | 2 history tickets shown, clear-all available |
| Menu grid corrected to **4 rows × 2 columns** at all 3 levels. | `lib/features/reporter/type_picker_page.dart` | S24 capture; 8×8×8 data intact |

---

## 2026-10-31 — accessibility, GPS map, photos, account, reset

| Change | Where | Evidence |
|---|---|---|
| **Accessibility profiles** for blind, mute, deaf, colorblind, motor and cognitive staff; text scale, high contrast, colorblind palette, visual alerts/vibration, spoken guidance, typed-first, large targets, simplified language. Applied globally via `MaterialApp.builder`. | `lib/core/accessibility/**`, `lib/main.dart`, login icon | settings screen captured; docs in `docs/accessibility.md` |
| **Live GPS map** with real location stream, schematic Craiova map, accuracy circle, coordinates and update status. | `lib/features/reporter/live_gps_map_screen.dart`, reporter button | screen captured |
| **Optional 5-second photo** prompt with a large camera button; photo is attached to the ticket and shown in dispatcher/dashboard detail. Report never waits more than 5 s. | `lib/features/reporter/photo_prompt.dart`, reporter flow, `photo_base64` wire field, dashboard/dispatcher photo | prompt captured; smoke 103/103 |
| **Quorum = one respondent per primary department** (instead of a global 2). | `backend/app/store.py`, demo tickets | low/medium resolve with fewer votes; fire+security needs 2 |
| **Employee account**: points (join +2, resolved +10) and attended incidents; visible from crew/dispatcher app bar. | `lib/features/account/account_screen.dart` | account screen captured |
| **Reset demo complet** in DevTools clears all tickets, history and therefore all points. | `lib/features/dev/dev_tools_screen.dart` | button + confirmation |
| Full `Screenshots/` folder committed to the repo, plus `docs/screenshots/` manifest for the PPTX. | `Screenshots/`, `docs/screenshots/` | 37 files / PPTX manifest |

---

## 2026-10-31 — modular domain profile, rewards and policies

| Change | Where | Evidence |
|---|---|---|
| **Application profile JSON** drives branding, feature switches, reward rules and quorum for both Flutter + FastAPI (`airport.json`; example `events.json`). | `config/domains/`, `lib/core/domain/domain_config.dart`, `backend/app/domain.py` | `/api/domain` smoke output; `flutter analyze` clean |
| **Rewards module** with pure `RewardPolicy` → `RewardLedger` → account UI; points/labels come from the profile, not the screen. | `lib/features/rewards/` | 7 new Flutter tests |
| **Quorum policy** (one per primary department or fixed) shared by app/server; store no longer hardcodes the count. | `lib/core/domain/quorum_policy.dart`, `backend/app/domain.py` | 4 Flutter + 3 backend unit tests |
| **Demo reset service**, **configurable notification rules**, and feature switches for rewards/GPS/photo/accessibility/reset. | `core/demo/`, `core/notifications/`, `main.dart`, reporter/account/crew/dispatcher | app tests 172; smoke 103/103 |
| **Domain unit tests + extension guide**: `docs/modularity.md`, `config/domains/README.md`. | docs/config | 7 backend unit tests pass |

---

## 2026-10-31 — real map tiles

| Change | Where | Evidence |
|---|---|---|
| Replaced the schematic GPS map with a real **OpenStreetMap slippy map** (`flutter_map` + `latlong2`): live marker, accuracy circle, follow/recenter, attribution, coordinates/accuracy. | `lib/features/reporter/live_gps_map_screen.dart` | S24 screenshot shows Craiova airport tiles + GPS marker (49 m accuracy) |
| Map provider/centre/zoom are profile-driven (`map` block in `config/domains/*.json`); OSM needs no API key, and the `tileUrl` seam allows a self-hosted tile server. | `lib/core/domain/domain_config.dart`, `config/domains/` | map loaded on device; analyze/tests clean |

---

## 2026-10-31 — persistent ticket media + Foto/Hartă toggle

| Change | Where | Evidence |
|---|---|---|
| Photo and GPS location are retained on the ticket and shown through a reusable **Foto/Hartă** toggle (photo tab + real OSM map with marker, accuracy/location text). | `lib/core/widgets/ticket_media_panel.dart` | dashboard screenshots: `21_ticket_media_photo.png`, `22_ticket_media_map.png` |
| Toggle available in **dispatcher detail, mobile dispatcher cards, crew expanded card, sent confirmation, history card and dashboard detail**. | dispatcher/crew/reporter screens, dashboard JS | dashboard photo/map tabs verified; Flutter widget tests |
| Location notification now advertises attached photo; report keeps photo/location through history/reset rules. | `core/notifications/ticket_notifier.dart`, ticket model | 174 Flutter tests; smoke 103/103 |

---

## 2026-10-31 — Mandy Medic + specific dispatch tags

| Change | Where | Evidence |
|---|---|---|
| Added **Mandy Medic** (`medic` / `medic123`), crew scoped to **Medical**. | `lib/core/auth/demo_accounts.dart`, login | account test; README accounts table |
| Added dedicated **`OP-MED`** medical emergency type, menu medical subcategory, AI/lexicon mapping and critical urgency. | `taxonomy.dart`, `incident_menu_data.dart`, `lexicon.dart`, `ai.py`, `backend/taxonomy.json` | 15-type taxonomy; smoke 103/103 |
| Centralized **`TicketTargeting`**: only primary departments are called/alerted; standby departments are displayed but not woken. | `core/targeting/ticket_targeting.dart`, crew queue, notifier | Mandy gets OP-MED; fire/security/terminal do not |
| Visible **required-team tags** ("Necesar: Medical / Pompieri / ...") on dispatcher cards/detail, crew cards, sent screen and dashboard. | `required_teams_bar.dart`, cards, dashboard JS | tags visible; dashboard detail "Echipe necesare" |
| Seed now includes a medical scenario so Mandy has a live job in the demo. | `backend/seed_demo.py` | 6 seeded scenarios |
