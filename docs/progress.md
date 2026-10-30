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
| Firewall rule "Wingman 8443" (inbound, any profile, TCP 8443) | `Get-NetFirewallRule` |
| Wi-Fi network profile set to **Private** | `Get-NetConnectionProfile` |
| Taxonomy authored (14 types / 4 categories, OP-OTHER catch-all) + backend JSON generated | `lib/core/incidents/taxonomy.dart`, `backend/taxonomy.json` |
| Contracts + docs + demo runbook written | `CONTRACTS.md`, `docs/` |
| Teammate distribution zip | `D:\Hackathon\Wingman-repo.zip` |

## In progress ⏳

| Item | Owner | Notes |
|---|---|---|
| Ollama install + `qwen2.5:7b` pull (~4.7 GB) | background job | then verify `/api/analyze` returns `ai_source: ollama` |
| JDK 17 + Android SDK (`platform-tools`, `android-35`, `build-tools;35.0.0`) | background job | required for APK builds |
| Phone ↔ laptop reachability on `HACKATHON-GUEST` | **user** | open `https://10.10.28.37:8443/` in the phone browser |
| First APK build + install on a physical Android | Lead | after SDK finishes: `.\scripts\build_demo_apks.ps1` |

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
