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
   forced-override.
4. **Accounts** (hardcoded, hashed passwords): `admin/admin123` (Andy Admin — sees and
   decides everything), `engineer/engineer123` (Earl Engineer — only maintenance/IT/baggage/
   airside), `janitor/janitor123` (John Janitor — only terminal incidents), `reporter/reporter123`
   (Rita Reporter). Sign in on the phones with the right scope for the story.
5. Phones: install `D:\Hackathon\dist\wingman-tls-release.apk` on 2-3 devices, open the app,
   confirm **„Server conectat"** on each. Keep charger connected, **Stay awake** ON.
6. **Desktop control room**: `.\scripts\serve_dashboard.ps1` → Edge opens fullscreen with the
   live dashboard (same store as the phones: REST snapshot + WSS live, confirm/deny/reclassify).
7. Emergency APK also installed: `wingman-insecure-release.apk` + `backend\run_insecure.ps1`.

## The 3 minutes

| Time | Who | Screen | What happens |
|---|---|---|---|
| 0:00 | Lead | laptop | One sentence: „Wingman turns a 30-second voice report into a dispatched, department-assigned ticket — fully offline, on this laptop." |
| 0:20 | Reporter phone (Rita) | Reporter | Hold mic → say: **„Este fum gros lângă poarta 12, în terminalul 1."** Release. Show transcription + AI card (SF-FIRE, critical, 95%, Poarta 12). Follow-up question → answer „Nimeni nu e rănit." → „Trimite". |
| 0:50 | Desktop (Admin) | Control room | New ticket appears live. Point at urgency counters/departments; open the **low-confidence** seeded ticket → Confirmă (or Reclasifică, showing the closed taxonomy). |
| 1:40 | Engineer phone | Echipaj | Sign in as **Earl Engineer** → only technical tickets (belt/bag/spill); fire/security are hidden. Tap **Preia** → **Rezolvat** (vote 1/2). |
| 2:05 | Janitor phone | Echipaj | Sign in as **John Janitor** → ONLY the terminal spill incident. „Different crew, different alert — same taxonomy." |
| 2:25 | Lead | laptop | The „why it's real" slide: local Qwen2.5 (0.3-0.6 s/classification on GPU), local Whisper, TLS pinned with a private CA, hashed demo accounts + department scoping, closed 14-type taxonomy with deterministic guards, `smoke 59/59` + 146 app tests, 5 s override + quorum server-side. |
| 2:50 | Lead | — | Close: offline-capable, no cloud keys, rebuildable APKs, desktop control room for ops. |

## Fallbacks (say nothing, keep moving)

- **Voice fails / noisy room** → „Scrie în loc să vorbești" typed path (same pipeline, verified).
- **Network hiccup** → menu button on reporter (14 types, no AI), shows the taxonomy.
- **Dispatcher confusion** → toggle **Demo** mode (pre-built urgency-colored scene, keyboard 1/2/3).
- **TLS issue on a phone** → install `wingman-insecure-release.apk`, start `backend\run_insecure.ps1`,
  20 s switch, no debugging on stage.
- **AI model missing** → backend falls back to deterministic keyword classifier; ticket still lands
  in the dispatcher override window (low confidence).

## Phrases the judges remember

- „Everything you just saw ran on this laptop: no cloud, no API key, no data leaving the room."
- „The 5-second window exists because the model is allowed to be unsure — the human is the tie-breaker."
- „14 closed types, not free text: the dispatcher always knows which department to wake up."
