# Build progress — live checklist

Updated: 2026-10-30 (H0 session). Tick items as they land.

## Done ✅

| Item | Evidence |
|---|---|
| Repo created at `D:\Hackathon\Wingman` (git, 2 commits) | `git log --oneline` |
| Toolchain installed (Git 2.56, Python 3.12.10, OpenSSL 4.1, Flutter 3.47.9 / Dart 3.13.7) | `flutter --version` |
| Flutter project scaffolded (android/, ios/, lib/, test/) | `flutter analyze` |
| TLS certs generated: **Wingman Local CA**, SAN `127.0.0.1`, `10.10.28.37`, `wingman.local`, `localhost` | `backend/certs/`, `assets/certs/ca.crt` |
| Backend venv + deps installed | `backend\.venv` (33 MB) |
| Backend running with TLS on 8443 | `https://10.10.28.37:8443/healthz` |
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
| Android bring-up fixes: release INTERNET permission, targetSdk 35 for Android 16 LAN policy, build-script dart-define bug, `kApiBase` sanitizer | `android/app/src/main/AndroidManifest.xml`, `build.gradle.kts`, `lib/main.dart` |

## In progress ⏳

| Item | Owner | Notes |
|---|---|---|
| Phone install + first boot | **user** | plug Android with USB debugging → `.\scripts\phone_run.ps1`; hotspot must be on (`.\scripts\hotspot_on.ps1`) |
| F1 voice integration | F1 + Lead | `/api/transcribe` live + `docs/whisper-contract.md`. Waiting for their `CONTRACT_REQUEST.md` to confirm field names / multipart-vs-base64; app-side recorder still to be added by F1 |
| Backlog: location gate (on-airport-only) | Lead | designed in `docs/backlog.md`; implement after H36 if stable |

## Next (H0–H4 remaining)

1. **Phone test (user, 2 min):** Safari/Chrome on one Android → `https://10.10.28.37:8443/`.
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
