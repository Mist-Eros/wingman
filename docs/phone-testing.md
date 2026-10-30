# Phone testing — step by step

Two separate things:
* **A. Network + certificate check** — 2 minutes, no app needed. Do this FIRST.
* **B. Install and run the Wingman app** — needs the APK or `flutter run`, and USB debugging.

Current state: backend is live at `https://10.10.28.37:8443`. The Android APK build is still
downloading Gradle on the laptop, so start with section A while it finishes.

---

## A. Network + TLS check (any phone, browser only)

1. Phone and laptop on the **same Wi-Fi** (`HACKATHON-GUEST` on this laptop).
2. Open Chrome (Android) / Safari (iPhone) → `https://10.10.28.37:8443/`
3. A certificate warning is **expected** (self-signed CA). Tap **Advanced → Proceed** (Chrome)
   or **Show Details → visit this website** (Safari).
4. You must see:

```text
Wingman API pornit ✔
Taxonomia v1 · 14 tipuri de incident · N tichete live.
```

5. Also check `https://10.10.28.37:8443/healthz` → JSON `{"status":"ok",...}`.

**If it loads** → network path works, continue to B.
**If it times out** → the guest Wi-Fi isolates clients; use the laptop hotspot:
`Settings → Network & internet → Mobile hotspot → ON`, connect all phones to it, then on the
laptop re-run `.\scripts\gen_certs.ps1 -Force` (adds `192.168.137.x` to the cert SAN) and
restart the backend. Send me the new IP.

### Optional: install the CA profile (removes the browser warning)

Only needed for the browser/system, **not** for the app (the app pins the bundled CA).

**Android:** download `https://10.10.28.37:8443/ca.crt` (tap through the warning) →
Settings → Security & privacy → More security settings → Encryption & credentials →
Install a certificate → CA certificate → "Install anyway" → pick `ca.crt` → confirm with
screen lock. Verify: Chrome shows no warning on `https://10.10.28.37:8443/`.

**iPhone:** open `https://10.10.28.37:8443/ca.crt` → Allow profile → Settings → General →
VPN & Device Management → *Wingman Local CA* → Install → then Settings → General → About →
Certificate Trust Settings → toggle **Full Trust ON** (this second step is mandatory).
Verify in Safari.

---

## B. Install the app on an Android phone (USB)

### B1. Enable USB debugging (once)

1. Settings → About phone → tap **Build number** 7 times → "You are now a developer".
2. Settings → System → Developer options → **USB debugging ON**.
3. Xiaomi/Redmi: also **USB debugging (Security settings)** and **Install via USB**.
4. Developer options → **Stay awake** ON (screen stays on while charging — good for the demo).

### B2. Connect and authorize

1. Plug a **data** USB cable into the laptop.
2. On the phone: "Allow USB debugging?" → check **Always allow** → Allow.
3. On the laptop:

```powershell
cd D:\Hackathon\Wingman
adb devices -l
# expected: <serial>  device  product:... model:...
```

If the list is empty / `unauthorized` / `no permissions`:
`adb kill-server; adb start-server; adb devices` and re-plug; accept the prompt again.
For OEM driver issues install the vendor USB driver (Samsung/Xiaomi/Pixel) or use wireless
debugging (B5).

### B3. Install + run

**Option 1 — one command (recommended once the APK exists):**

```powershell
.\scripts\phone_run.ps1
```

What it does: waits for the phone, installs the newest APK (from `D:\Hackathon\dist` or
`build\app\outputs\flutter-apk\`), launches Wingman and shows the app logs.
Add `-NoLogs` to skip the log tail, `-Apk <path>` to install a specific APK.

**Option 2 — manual:**

```powershell
# build (debug is faster; release is what you install for the demo)
flutter build apk --debug `
  --dart-define=API_BASE=https://10.10.28.37:8443 `
  --dart-define=API_TOKEN=demo-token

adb install -r build\app\outputs\flutter-apk\app-debug.apk
adb shell am start -n com.wingman.wingman/.MainActivity
```

**Option 3 — live dev loop with hot reload (best while coding):**

```powershell
flutter devices
flutter run -d <device-id> `
  --dart-define=API_BASE=https://10.10.28.37:8443 `
  --dart-define=API_TOKEN=demo-token
# r = hot reload, R = hot restart, q = quit
```

### B4. Build the demo APKs (TLS + emergency HTTP)

```powershell
.\scripts\build_demo_apks.ps1
# -> D:\Hackathon\dist\wingman-tls-release.apk
# -> D:\Hackathon\dist\wingman-insecure-release.apk
```

Install **both** on every demo phone. If TLS misbehaves on stage, start
`backend\run_insecure.ps1` and open the insecure app — 20 seconds, no debugging.

### B5. Wireless debugging (no cable, Android 11+)

1. Phone and laptop on the same Wi-Fi.
2. Developer options → **Wireless debugging** → ON → *Pair device with pairing code*.
3. Laptop:

```powershell
adb pair <phone-ip>:<pair-port> <6-digit-code>
adb connect <phone-ip>:<debug-port>     # shown on the Wireless debugging screen
flutter devices
```

---

## C. What to check in the app (smoke checklist)

| # | Check | Expected |
|---|---|---|
| 1 | App opens | role picker with 3 cards + green "Server conectat" |
| 2 | Choose **Raportor** | reporter screen (stub for now), ticket count visible |
| 3 | Choose **Dispecer** on a 2nd phone | live ticket list, pending-override section at top |
| 4 | Report from phone 1 (menu) | ticket appears on phone 2 in < 1 s (WSS) |
| 5 | Dispatcher confirm/deny | status changes on both phones |
| 6 | Choose **Echipaj**, join + vote | progress `1/2` → resolved on all devices |
| 7 | Kill Wi-Fi on a phone, re-enable | app reconnects, badge goes green again |

Backend truth check from the laptop:

```powershell
python scripts\smoke_test.py --ca backend\certs\ca.crt     # 50 checks
python backend\seed_demo.py                                # demo data
```

---

## D. Troubleshooting

| Symptom | Cause / fix |
|---|---|
| Browser: `NET::ERR_CERT_AUTHORITY_INVALID` | Expected (self-signed). Tap Advanced → Proceed, or install the CA (section A). |
| Browser: page times out | Wrong Wi-Fi / client isolation / laptop asleep / backend stopped. Check `https://10.10.28.37:8443/healthz` from the laptop itself; use hotspot fallback. |
| `adb devices` empty | Cable is charge-only, USB debugging off, or driver missing. Re-plug, accept prompt, `adb kill-server`. |
| `adb devices` = `unauthorized` | Accept the RSA prompt on the phone (check "Always allow"). |
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | Another build with a different signature: `adb uninstall com.wingman.wingman` then install again. |
| `INSTALL_FAILED_INSUFFICIENT_STORAGE` | Free space on the phone. |
| App: "Cannot reach https://…" | Phone not on the same network, wrong `API_BASE`, backend down, firewall. |
| App: "TLS handshake failed" | IP not in the certificate SAN, or the CA asset is stale → `gen_certs.ps1 -Force`, `flutter pub get`, rebuild, reinstall. |
| App: "Contract mismatch" | App and backend from different commits — pull the repo, rebuild. |
| App closes on launch | Watch `adb logcat -s flutter` (or `phone_run.ps1` logs) — usually a missing asset or an unhandled exception in a feature screen. |
| Mic permission denied | App info → Permissions → Microphone → Allow; or reset via Developer options. |
| App disconnects when screen off | Battery optimization: Settings → Apps → Wingman → Battery → Unrestricted; developer option **Stay awake** for demos. |

---

## E. iPhone notes (2 iPhones in the plan)

The app **cannot be built on Windows** (Flutter iOS requires macOS/Xcode). Until the cloud-Mac
build (decided: later), iPhones can be used for:

1. **Browser check** (section A) — proves the network/TLS and the CA profile work on iOS.
2. Demo role of "second screen" only after a Mac builds the IPA (needs an Apple Developer
   account for installing on a physical device, or free 7-day provisioning from Xcode).

Do the iPhone CA profile install today anyway (section A) — it's the part that always bites at
the last minute.
