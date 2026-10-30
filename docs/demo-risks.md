# Demo risks and pre-built fallbacks

Rule: every risk below gets a **fallback that already exists on the laptop** before H36 — not a
plan to improvise at T-5 minutes. The demo script never depends on anything that is not
covered here.

---

## R1 — Ollama / AI fails or is too slow at the worst moment

**Why it happens:** model not pulled or OOM after other apps opened; cold load 30–90 s on a
7B/8B model; `ollama serve` not started after reboot; laptop on battery throttling;
Wi-Fi/latency; model returns a code outside the taxonomy.

**Early warning:** `GET /api/health` → `ollama.reachable` false / `last_error` non-null;
`POST /api/reports` voice path takes > 15 s; backend log shows `Ollama classify failed`).

**Pre-built fallbacks (all shipped):**
1. **Warm-up at boot** — the backend loads the model with `keep_alive: 30m` on startup; `/api/health`
   shows `last_ok` and the available models list.
2. **Deterministic keyword classifier** (`backend/app/ai.py::fallback_classify`) — any Ollama
   failure degrades to a keyword match with confidence ≤ 0.58, which lands the ticket in the
   **dispatcher 5-second override** flow. The AI being down becomes a *feature*, not an error.
3. **Server-side validation** — the AI's `incident_code` is checked against the closed taxonomy;
   unknown codes are re-mapped or fall back. A hallucinated code can never reach the UI.
4. **Menu flow is AI-free** — `hint_code` + `use_ai: false` dispatches instantly with
   confidence 1.0. If the model is unusable on stage, the reporter uses the button menu.
5. **`force_override` demo switch** — `POST /api/reports {"force_override": true}` guarantees a
   visible 5-second override window regardless of model confidence (used by `backend/seed_demo.py`).
6. **Seeded golden tickets** — 4 tickets are one command away (`python backend/seed_demo.py`);
   the dispatcher and crew screens are never empty on stage.
7. **Model swap** — if qwen2.5:7b is slow on the laptop, `ollama pull llama3.1:8b` and
   `$env:OLLAMA_MODEL='llama3.1:8b'; .\run.ps1` — no code change. If both are slow, use the
   smaller `qwen2.5:3b` for the demo (quality drop is invisible in a 6-minute script).

**Owner:** Lead. **Check at:** H24, H32, H36, and 10 min before demo (`scripts/preflight.ps1`).

---

## R2 — Phones can't reach the laptop / TLS fails on stage

**Why it happens:** phones on guest Wi-Fi or different subnet; router AP isolation; Windows
firewall switched to Public profile; laptop IP changed by DHCP; CA asset not rebuilt after a
cert regeneration; iOS profile installed but full trust not toggled; Android 7+ not trusting
user CAs (expected — the app pins instead); VPN/private DNS on a phone.

**Early warning:** role screen shows "Server offline"; `TLS handshake failed` vs
`Cannot reach` in the error banner tells you which one; `scripts/preflight.ps1` fails.

**Pre-built fallbacks (all shipped):**
1. **CA pinned in the app** (`lib/core/api/api_client.dart`) — works even if no phone profile is
   installed. This is the primary path; the profile only matters for Safari/Chrome checks.
2. **Multi-IP SAN** — `gen_certs.ps1` puts every detected private IPv4 in the certificate, plus
   `-ExtraIps`, so a DHCP change between two known subnets does not break TLS.
3. **Emergency HTTP build, pre-installed on every phone** — `backend\run_insecure.ps1` (port
   8080) + an app build with `--dart-define=API_BASE=http://<ip>:8080 --dart-define=DEV_INSECURE=true`.
   Build and install it at H30; it is a separate app install, so switching is 20 seconds.
4. **Laptop hotspot** — the most reliable network: phone hotspot vs laptop hotspot both tested.
   Re-run `gen_certs.ps1 -Force` after the IP changes (SAR now includes the hotspot subnet) or
   use the HTTP build.
5. **Two pre-built API_BASE builds** — one `.apk` for the venue Wi-Fi IP, one for the hotspot IP
   (same TLS cert if both IPs are in the SAN — then one build for both).
6. **Seed data + local demo** — even with zero phones connected, the dispatcher screen on the
   laptop shows seeded tickets; the video backup covers the rest.
7. **Firewall runbook** — `New-NetFirewallRule ... -Profile Private` command in
   `docs/certs-and-phones.md` §2; check the Wi-Fi profile is Private, not Public.

**Owner:** Lead. **Check at:** H30 (hotspot test), H36, and T-15 min.

---

## R3 — Integration rot breaks the demo path at the last minute

**Why it happens:** a teammate merges a feature that compiles but throws at runtime; someone
"fixes" a core file; a hot-reloaded screen behaves differently on a cold start; the last merge
after the freeze is untested; four people editing `pubspec.yaml`.

**Early warning:** `flutter analyze` warnings appear; the role picker no longer boots; a screen
shows a red error box; `git log main` has commits after the freeze tag.

**Pre-built fallbacks (all shipped):**
1. **Stubs that always work** — every feature screen has a compiled stub that renders live core
   data, so `main` boots even if a feature folder is reverted.
2. **Feature isolation** — the three folders are independent; reverting one teammate's PR never
   touches the other two. `git revert <sha>` is the play, not a hotfix.
3. **Contract gate** — `scripts/smoke_test.py` (37 checks incl. exact ticket JSON keys),
   `scripts/sync_taxonomy.py`, and `flutter analyze` run at every integration window.
4. **`demo-ready` tag at H36** — from that moment `main` is frozen; any demo-day fix is a
   cherry-pick onto a `demo` branch, tested on one device, and the tag remains the fallback
   (`git checkout demo-ready`).
5. **Full-flow screen recording** made at H34 on the 4 devices, on the laptop, plus screenshots
   of each state (pending override, dispatched, resolved). If the live demo dies, the team
   presents the video and keeps talking — no dead air.
6. **One-command reset** — `POST /api/dev/reset` + `seed_demo.py` restores the demo state in
   10 seconds between rehearsals.
7. **Named owner during demo** — one person drives, one person watches the laptop terminal, one
   person handles devices. Only the driver talks.

**Owner:** Lead. **Check at:** every integration window + H36.

---

## Runners-up (short list, same rule)

| # | Risk | Pre-built fallback |
|---|---|---|
| R4 | **No Mac in the team ⇒ no iOS build.** Flutter iOS requires macOS/Xcode. | Decide at H2. If no Mac: demo on 2 Androids + 2 emulators, drop iOS from the live demo (code still ships), or borrow/cloud-build (Codemagic) early — never at H40. |
| R5 | On-device STT fails (permissions, language, noise) | Reporter screen keeps a text field + 5 preset transcripts; the menu flow needs no speech at all. |
| R6 | Laptop battery/thermal throttle | Charged + plugged in; close Chrome tabs/OBS; `flutter run --profile` instead of debug if jank appears. |
| R7 | Judge asks "is this really encrypted / secure?" | Answer with the actual path: TLS 1.3 WSS + private CA pinned in the app, bearer token per device, `flutter_secure_storage` for tokens, no at-rest data in the demo store; say plainly that auth is demo-grade and what production would add (mTLS, short-lived tokens, audit log). |
| R8 | Wi-Fi/venue network hostile | Laptop hotspot is the primary network at the venue; phones auto-join it; HTTP fallback build covers TLS breakage. |

---

## Demo script (6 minutes, rehearse to 5:30)

| Time | Who | Beat | Fallback if it fails |
|---|---|---|---|
| 0:00–0:30 | Lead | Problem + one-sentence product: *"Wingman — the airport's extra pair of eyes: closed taxonomy, human-in-the-loop, on-prem AI."* | — |
| 0:30–1:30 | Reporter (iPhone) | Voice report: *"Este fum lângă poarta 12..."* → processed card with code SF-FIRE, urgency Critică, Pompieri + Securitate | Use menu flow (SF-FIRE) — same screen, instant |
| 1:30–2:30 | Dispatcher (tablet/phone 2) | Card appears live (WSS); confidence chip; show the **5 s countdown** on the forced low-confidence ticket → confirm/reclassify | Use seeded pending-override ticket (`seed_demo.py`) |
| 2:30–3:30 | Crew (phone 3) | Dispatch arrives → **Preia** → **Rezolvat** vote; counter 1/2 | Pre-seeded ticket already in crew queue |
| 3:30–4:15 | Crew (phone 4) | Second vote → card flips to **Rezolvat** everywhere simultaneously (WSS) | Show resolved screenshot |
| 4:15–5:15 | Lead | Architecture: FastAPI + WSS hub, Ollama prompt constrained to 14 codes, validation, fallback classifier, 5 s override, TLS 1.3 + pinned CA; why closed taxonomy prevents hallucinated codes | Architecture slide |
| 5:15–6:00 | Lead | What ships next: audit trail, mTLS, real dispatch integration; close | — |

**Golden rule:** if a live beat stalls for more than 10 seconds, say "and here's the same flow
recorded end-to-end" and cut to the video. Never debug in front of judges.

---

## T-30 / T-10 checklist

**T-30 min**
- [ ] `scripts/preflight.ps1` all green
- [ ] backend restarted **with** `run.ps1` (TLS), warm-up log line visible
- [ ] `python backend/seed_demo.py --reset`
- [ ] all 4 phones unlocked, app open on the role picker, brightness 100%, notifications off
- [ ] laptop: charger, video backup, slides, `git status` clean, `demo-ready` tag present

**T-10 min**
- [ ] one full dry run of beats 1–3 (report → dispatch → join) to confirm the network is alive
- [ ] `seed_demo.py --reset` again if the dry run dirtied the state
- [ ] phones in a row on the table in role order; one person owns each
- [ ] close everything non-essential on the laptop
