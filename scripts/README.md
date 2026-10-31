# Automation scripts

Run PowerShell scripts from the repo root (`powershell -ExecutionPolicy Bypass -File ...`).
Python scripts use the backend virtualenv (`backend\.venv\Scripts\python.exe`).

## Demo / runtime

| Script | What it does |
|---|---|
| `serve_dashboard.ps1` | Opens the live control room in Waterfox (trusts the CA in a dedicated profile). `-Flutter` serves the optional CanvasKit version over HTTP for Chromium. |
| `dashboard/` | The zero-dependency HTML control room (report form, live WSS queue, actions). |
| `build_demo_apks.ps1 -ApiHost <ip>` | Builds `wingman-tls-release.apk` + `wingman-insecure-release.apk` into `D:\Hackathon\dist`. |
| `run` entrypoints are in `backend\run.ps1` / `backend\run_insecure.ps1` | Start the TLS backend (:8443) or the emergency plain-HTTP fallback (:8080). |
| `hotspot_on.ps1` | Starts the laptop hotspot fallback network for the phones. |
| `phone_run.ps1` | `flutter run` on a USB phone with the correct `--dart-define` values. |
| `preflight.ps1` | Pre-demo checks: network, certs, backend health, Ollama, phone reachability. |

## Certificates / model

| Script | What it does |
|---|---|
| `gen_certs.ps1 [-Force]` | Creates the private CA + server certificate with multi-IP SAN, copies the CA into `assets/certs/ca.crt`. |
| `prepare_ollama_model.ps1` | Builds the Ollama model from the official HuggingFace GGUF when the registry stalls. |
| `check_stt.ps1` | Verifies faster-whisper STT works on the laptop. |

## Verification

| Script | What it does |
|---|---|
| `verify_all.ps1 [-Live]` | One command: taxonomy sync, wire parity, analyze, app tests, smoke, live Dart tests. |
| `smoke_test.py` | Backend end-to-end gate (88 checks: auth, WSS, immediate dispatch, votes, zones, STT, wire keys). |
| `check_wire_parity.py` | Offline check that Dart JSON mapping and FastAPI schemas agree. |
| `sync_taxonomy.py [--write]` | Regenerates `backend/taxonomy.json` from `lib/core/incidents/taxonomy.dart`. |
