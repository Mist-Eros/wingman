# 3-minute demo script (rehearsal-ready)

## T-10 minutes checklist

1. Laptop on the **same Wi-Fi** as the phones (currently `StormTP-link`, laptop `192.168.0.170`).
   - If the network changes: `.\scripts\gen_certs.ps1 -Force` then rebuild the APK with the new IP
     (`.\scripts\build_demo_apks.ps1 -ApiHost <ip>`), reinstall.
   - Fallback network: laptop hotspot — `.\scripts\hotspot_on.ps1` (SSID `DESKTOP-ET39230 5531`,
     password `E032{07h`), phones join it, cert must include `192.168.137.1`.
2. Backend: `cd backend; .\run.ps1` (TLS 8443). Health: `https://<ip>:8443/healthz`.
   - AI: `ollama serve` + model `qwen2.5:1.5b` (health → `ollama.last_ok: true`).
   - STT: `STT available: true` (first transcription may load the model, ~1 s extra).
3. Seed the stage data: `python backend\seed_demo.py --base https://<ip>:8443 --reset`
   → 5 tickets: fire/smoke (critical), unattended bag, belt fault (menu), spill (janitor),
   a low-confidence report.
4. **Accounts** (hardcoded, hashed passwords): `admin/admin123` (Andy Admin — sees and
   decides everything), `engineer/engineer123` (Earl Engineer — maintenance/IT/baggage/airside),
   `janitor/janitor123` (John Janitor — terminal only), `firefighter/firefighter123`
   (Fred Firefighter — fire/rescue), `guard/guard123` (Gina Guard — security).
   There is no reporter account; **anyone can report** from the crew/dispatcher screens or the
   PC dashboard.
5. Phones: install `D:\Hackathon\dist\wingman-tls-release.apk`, sign in as **Earl Engineer** and
   **John Janitor**, confirm **„Server conectat"**, and allow notifications on the first sign-in
   (system prompt). Keep charger connected, **Stay awake** ON, app open on the crew screen —
   notifications are local (no cloud push), so the phone must stay connected to the laptop.
6. **Desktop control room**: `.\scripts\serve_dashboard.ps1` → **Waterfox** opens with the live
   dashboard (same store as the phones: REST snapshot + WSS live, Coadă/Istoric, deny/reclassify, clear history).
   Waterfox is launched with the dedicated demo profile so our CA is trusted automatically.
7. **DevTools** (for Q&A / photos): on the login screen tap the **wrench icon** (top-right) to
   preview every time-of-day sky look, see live Ollama/STT/WSS health, simulate a report,
   reset the store, or check the account scopes.
8. **Progress screenshots**: `D:\Hackathon\ProgressPics\Steep_01…09` — one folder per milestone
   (toolchain → crew → dispatcher → reporter → design → accounts → dashboard → skies → final).
9. Emergency APK also installed: `wingman-insecure-release.apk` + `backend\run_insecure.ps1`.

## The 3 minutes

| Time | Who | Screen | What happens |
|---|---|---|---|
| 0:00 | Lead | laptop | One sentence: „Wingman turns a 30-second voice report into a dispatched, department-assigned ticket — fully offline, on this laptop." |
| 0:15 | Admin on PC | Waterfox dashboard | Press **N** → type „A luat foc un calculator la intrare, terminalul de sosiri", → **Ctrl+Enter**. Point at the live ticket + AI code (SF-FIRE) and location (Intrarea principală). |
| 0:40 | Crew phone | Notification | The phone buzzes: „🚨 SF-FIRE · Foc sau fum…" (firefighters + security only — Fred/Gina). Open it. |
| 1:00 | Engineer phone | Echipaj | Sign in as **Earl Engineer** → the same ticket is there; tap **Preia** → **Rezolvat** (vote 1/2). |
| 1:30 | Janitor phone | Echipaj | Sign in as **John Janitor** → only terminal incidents (spill shown, security/bag hidden). „Different crew, different alert." |
| 2:00 | Admin | Dashboard | Show urgency counters + ticket detail; Reclasifică shows the closed 14-type taxonomy. |
| 2:30 | Lead | laptop | „Why it's real": local Qwen2.5 (0.3–0.6 s/classification), local Whisper, TLS pinned private CA, hashed demo accounts + department scoping + **scoped Android notifications**, 14-type taxonomy with deterministic guards, gates green, immediate dispatch + quorum server-side. |
| 2:50 | Lead | — | Close: offline-capable, no cloud keys, rebuildable APKs, desktop control room for ops. |

## Fallbacks (say nothing, keep moving)

- **Voice fails / noisy room** → „Scrie în loc să vorbești" typed path (same pipeline, verified).
- **Network hiccup** → menu button on reporter (14 types, no AI), shows the taxonomy.
- **Dispatcher confusion** → toggle **Demo** mode (pre-built urgency-colored scene, keyboard 1/2/3).
- **TLS issue on a phone** → install `wingman-insecure-release.apk`, start `backend\run_insecure.ps1`,
  20 s switch, no debugging on stage.
- **AI model missing** → backend falls back to deterministic keyword classifier; ticket still lands
  in the dispatcher queue for deny/reclassify.

## Phrases the judges remember

- „Everything you just saw ran on this laptop: no cloud, no API key, no data leaving the room."
- „The model is allowed to be unsure — every ticket lands in front of a human, who can deny or reclassify it."
- „14 closed types, not free text: the dispatcher always knows which department to wake up."

