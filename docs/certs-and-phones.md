# Certs and phones - operator runbook

For the person driving the laptop and the 4 test phones (2 iPhones, 2 Androids). Run every command from the repo root unless stated otherwise.

Locked facts: one FastAPI/uvicorn process on **port 8443** serves both HTTPS REST and WSS over the same TLS listener. We use a **private CA** whose certificate is bundled into the Flutter app as `assets/certs/ca.crt`; tokens stay in `flutter_secure_storage` (Keychain/Keystore).

---

## 1. What we are doing and why

- We terminate **TLS 1.3** in uvicorn: REST and WSS share one listener, so the app talks to one origin (`https://<laptop-ip>:8443` and `wss://<laptop-ip>:8443/...`).
- A private CA (`ca.crt`/`ca.key`) signs a short-lived leaf (`server.crt`, 397 days, RSA-2048, SHA-256) with a **Subject Alternative Name** covering the laptop's LAN IPs + DNS names. SAN is mandatory: iOS rejects CN-only certificates, and IPs are what the phones actually use.
- The CA is **pinned in the app bundle** (`assets/certs/ca.crt`) so dart:io trusts exactly our CA for the REST/WSS connections.
- The same CA is installed on the phones so Safari/Chrome and system traffic trust `https://<laptop-ip>:8443/healthz`; the backend also serves the CA itself at `/ca.crt`.
- Why not a public CA: no domain, LAN-only IP endpoints, 48-hour lifetime. Why not `badCertificateCallback`: it disables verification for every host - wrong for credentials.

## 2. One-time laptop setup

```powershell
# 1) Install OpenSSL (PowerShell 7 or Windows PowerShell 5.1; no admin tricks needed)
winget install --id ShiningLight.OpenSSL.Light -e
# then open a NEW terminal so PATH refreshes

# 2) Generate the CA + leaf and copy the CA into the Flutter assets
.\scripts\gen_certs.ps1 -Force
```

Expected output (abridged):

```text
== OpenSSL
  [ok]   Version: OpenSSL 3.5.x ...
== Detecting laptop IPv4 addresses
  192.168.1.23   Wi-Fi      Wi-Fi        IN SAN | USE THIS
== Files written
  [ok]   backend\certs\ca.key ... backend\certs\server.crt ...
  [ok]   assets\certs\ca.crt ... copy of the CA bundled into the Flutter app
== Start the backend (run from the backend folder)
  uvicorn app.main:app --host 0.0.0.0 --port 8443 --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt
```

Verify:

```powershell
# SAN is really there (must print the Subject Alternative Name line)
openssl x509 -in backend/certs/server.crt -noout -text | findstr /C:"Subject Alternative Name"

# Start backend in terminal 1 (run.ps1 does exactly this + prints the phone URLs):
cd backend
python -m uvicorn app.main:app --host 0.0.0.0 --port 8443 --ssl-keyfile certs/server.key --ssl-certfile certs/server.crt

# Terminal 2, from repo root - the CA must validate the running listener
openssl s_client -connect 127.0.0.1:8443 -CAfile backend/certs/ca.crt
# expect: "Verify return code: 0 (ok)"; press Ctrl+C to exit
```

Start the app with the URL the script printed (the backend token is in `backend\.env.example` / `backend\run.ps1`):

```powershell
flutter run --dart-define=API_BASE=https://<LAPTOP_IP>:8443 --dart-define=API_TOKEN=demo-token
```

Open the firewall once, in an **elevated** PowerShell (and make sure the network profile is Private):

```powershell
New-NetFirewallRule -DisplayName "Wingman 8443" -Direction Inbound -Protocol TCP -LocalPort 8443 -Action Allow -Profile Private
Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
```

## 3. CRITICAL: installing the CA on the phone does NOT fix the Flutter app

`dart:io` (`HttpClient`, `WebSocket`) is **not** the browser and does not give you the browser's trust model: user-installed CAs are not reliably used for app traffic (on Android 7+ apps do not trust user-added CAs by default, and you should not rely on the iOS system-store path either). Installing the profile alone will still produce `CERTIFICATE_VERIFY_FAILED` / `HandshakeException` in the Flutter app.

The app must explicitly trust the bundled CA and pass that context to both HTTP and WS (already implemented in `lib/core/api/api_client.dart`):

```dart
// main.dart: CA loaded from the asset declared in pubspec.yaml, passed as PEM
final caPem = await rootBundle.loadString('assets/certs/ca.crt');
final api = ApiClient(baseUrl: 'https://<laptop-ip>:8443', token: 'demo-token', caPem: caPem);
// ApiClient: SecurityContext(withTrustedRoots: true)
//   ..setTrustedCertificatesBytes(pem);  then HttpClient(context: ...) for REST
//   and WebSocket.connect(url, customClient: <same-context client>)
```

`ApiClient` tries PEM, then DER (base64-decoded from the same file), and only then falls back to the platform trust store, printing a `[tls]` warning at boot. If you see that warning on an iPhone, the installed profile becomes load-bearing — re-check section 4's full-trust toggle.

Installing the profile is still required: it makes Safari/Chrome accept the URL, lets the phone download files, and is belt-and-braces for system-stack traffic. Both are needed: profile for browsers, pinned CA for the app.

## 4. iPhone install (do this on BOTH iPhones)

1. Get `backend/certs/ca.crt` onto the phone: LAN download page/QR (section 9), email attachment, or AirDrop if a Mac is around.
2. Tap the downloaded file -> "Profile Downloaded".
3. **Settings -> General -> VPN & Device Management -> "Wingman Local CA" -> Install** -> enter the device passcode -> Install -> Done.
4. **Settings -> General -> About -> Certificate Trust Settings -> toggle "Wingman Local CA" to ON.** This second step is the #1 mistake; installing without it leaves the CA untrusted. iOS 18/19 still use these same two menus.
5. Verify in **Safari**: open `https://<LAPTOP_IP>:8443/` (human status page - it literally tells you whether the CA is trusted on this device) or `https://<LAPTOP_IP>:8443/healthz` (JSON). No certificate warning allowed.

## 5. Android install (do this on BOTH Androids)

1. Copy `ca.crt` to **Downloads** (USB/MTP, email, or LAN download/QR from section 9). The file **must end in `.crt`** for the installer to accept it.
2. Stock Android 14/15/16 path: **Settings -> Security & privacy -> More security settings -> Encryption & credentials -> Install a certificate -> CA certificate -> "Install anyway"** (RO: "Instalează oricum"; warning screen) -> choose `ca.crt` from Downloads -> confirm with the screen lock.
3. Android 14+ requires a **screen lock (PIN/pattern/password)** before it will install a CA; set one if the phone has none.
4. Verify in **Chrome**: open `https://<LAPTOP_IP>:8443/` (human status page; it also links the CA download) or `https://<LAPTOP_IP>:8443/healthz` - JSON, no warning.

OEM path variations (the flow is the same, the menus move):

- **Pixel/stock** - exactly the path above.
- **Samsung (One UI 6/7)** - the sub-page is usually labelled "Install from device storage" instead of "Install a certificate": Settings -> Security and privacy -> More security settings -> Install from device storage -> CA certificate.
- **Xiaomi (HyperOS/MIUI)** and **OnePlus (OxygenOS)** - menu location varies by version (Privacy/Security section, sometimes under "Encryption & credentials"). The reliable fallback on every OEM: open **Settings and search "CA certificate"** (Romanian UI: search "certificat"), then follow that entry.

## 6. Per-device sign-off

| Device / OS | CA profile installed | Full trust enabled (iOS) | Safari/Chrome https check OK | App connects (WSS) | Signed off by |
|---|---|---|---|---|---|
| iPhone 1 - iOS | [ ] | [ ] | [ ] | [ ] | |
| iPhone 2 - iOS | [ ] | [ ] | [ ] | [ ] | |
| Android 1 - Android | [ ] | n/a | [ ] | [ ] | |
| Android 2 - Android | [ ] | n/a | [ ] | [ ] | |

## 7. Troubleshooting

| Symptom | Fix |
|---|---|
| App: `CERTIFICATE_VERIFY_FAILED` / `HandshakeException` even though Chrome shows the lock | The app did not trust the bundled CA, or the URL host is not in the SAN. Check `assets/certs/ca.crt` exists and is declared in `pubspec.yaml`, that `SecurityContext.setTrustedCertificatesBytes` is applied to the `HttpClient` used by both REST and `WebSocket.connect(customClient: ...)`, and that the host in the URL is one the script printed. Rebuild after changing assets. |
| Browser: `ERR_CERT_AUTHORITY_INVALID` / warning page | CA profile not installed on that phone, or trusted-install skipped (on iOS: Certificate Trust Settings OFF). Reinstall the profile and check the full-trust toggle; compare the CA fingerprint printed by the script. |
| `Hostname mismatch` / "certificate is not valid for this name" | You are using a host (IP or DNS name) that is not in the SAN. Use an address the script listed, or re-run `.\scripts\gen_certs.ps1 -Force -ExtraIps <ip>` / `-Dns <name>`. Any `-Force` run creates a **new CA**, so reinstall `ca.crt` on all 4 phones afterwards. |
| Laptop IP changed after DHCP | Best: set a **DHCP reservation** for the laptop on the router before demo day. Otherwise re-run `.\scripts\gen_certs.ps1 -Force` (reinstall `ca.crt` on all phones and rebuild/relaunch the app if the asset was rebuilt), then update the app URL. |
| Phones cannot reach the laptop at all (timeout, no response) | Wrong network/subnet or blocked traffic: same Wi-Fi/LAN? Guest network or "AP/client isolation" blocks phone-to-laptop traffic - use the main SSID or the laptop hotspot. Windows firewall must allow 8443 on a **Private** profile: re-run the firewall command, check `Get-NetConnectionProfile`, and confirm TCP from the phone's browser. |
| Android app still fails while Chrome works | Expected on Android 7+: apps targeting API 24+ do not trust user-installed CAs by default. That is exactly why the app pins `assets/certs/ca.crt`; the profile is only for the browser/system. |
| VPN or private DNS on the phone | VPNs and some private-DNS setups block/redirect LAN traffic. Disable VPN (and "Private DNS"/"Secure DNS") while testing, or whitelist the LAN. |
| Nothing works, 15 minutes left | Laptop hotspot fallback: enable Mobile hotspot, note the new IP (often `192.168.137.1`), re-run `.\scripts\gen_certs.ps1 -Force`, reinstall the CA (QR page), or use the plain-HTTP fallback in section 8. |

## 8. Demo-day emergency fallback (TLS on phones failing at T-15)

```powershell
.\backend\run_insecure.ps1                                   # plain HTTP/WSS on :8080, no TLS
flutter run --dart-define=DEV_INSECURE=true --dart-define=API_BASE=http://<LAPTOP_IP>:8080 --dart-define=API_TOKEN=demo-token
```

This is **dev-only**: it disables TLS and certificate verification for the demo; never ship it and revert both flags/files immediately after. If the script ever goes missing, `cd backend` and run `uvicorn app.main:app --host 0.0.0.0 --port 8080` without the `--ssl-*` flags.

## 9. QR shortcut (fastest install path)

Serve the certs folder over plain HTTP (fine - the CA certificate is public), then generate one QR code per laptop IP:

```powershell
python -m http.server 8081 --directory backend/certs
# or, if Python is not installed:
npx serve backend/certs -l 8081
```

Generate a QR for `http://<LAPTOP_IP>:8081/ca.crt` (any QR generator; keep the phone on the same Wi-Fi), scan it on each phone, download the file, then follow section 4 (iPhone) or section 5 (Android). Note: the backend also serves the same CA at `https://<LAPTOP_IP>:8443/ca.crt` (public, no token), but before the CA is trusted the browser shows a warning - tap through it or prefer the QR/HTTP route. If the laptop has neither Python nor Node, email `ca.crt` to the phones or copy it over USB.
