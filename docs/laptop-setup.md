# Laptop setup notes — this machine (current state)

Recorded after the H0 setup session. **Do not repeat these installs.**

## Installed

| Tool | Version | Location | Notes |
|---|---|---|---|
| Git | 2.56.0 | `C:\Program Files\Git` | repo initialised at `D:\Hackathon\Wingman` |
| Python | 3.12.10 | `%LOCALAPPDATA%\Programs\Python\Python312` | backend venv at `backend\.venv` (33 MB) |
| OpenSSL | 4.1.0 | `C:\Program Files\OpenSSL-Win64\bin` | not on PATH in old terminals; `gen_certs.ps1` probes for it |
| Flutter | 3.47.9 (Dart 3.13.7) | `C:\dev\flutter\bin` | added to the **user** PATH; open a new terminal to use `flutter` |
| Ollama | installing | `%LOCALAPPDATA%\Programs\Ollama` | `qwen2.5:7b` model pulling in the background |
| JDK 17 + Android SDK | installing | `C:\Android\sdk` | `platform-tools`, `android-35`, `build-tools;35.0.0` |

## TLS (already generated)

- CA: `backend/certs/ca.crt` (also bundled in the app as `assets/certs/ca.crt`)
- CA name: **Wingman Local CA** (that's the profile name on phones)
- Leaf SAN: `IP 127.0.0.1`, `IP 10.10.28.37`, `DNS wingman.local`, `DNS localhost`
- Laptop LAN IP right now: **10.10.28.37** (Wi-Fi `HACKATHON-GUEST`)
- `192.168.56.1` is a VirtualBox host-only adapter — **not reachable from phones**, ignore it

If the IP changes (hotspot, other network), regenerate and reinstall the phone profile:

```powershell
.\scripts\gen_certs.ps1 -Force
```

## Start the stack

```powershell
cd D:\Hackathon\Wingman\backend
.\run.ps1                     # TLS 8443; installs nothing (venv already populated)

# second terminal
cd D:\Hackathon\Wingman
python backend\seed_demo.py   # demo data
python scripts\smoke_test.py --ca backend\certs\ca.crt   # 37 checks, strict TLS
```

Flutter app (after `flutter pub get` in `D:\Hackathon\Wingman`):

```powershell
flutter run --dart-define=API_BASE=https://10.10.28.37:8443 --dart-define=API_TOKEN=demo-token
```

## Gates that must stay green

```powershell
flutter analyze
flutter test
python scripts\sync_taxonomy.py
python scripts\check_wire_parity.py
python scripts\smoke_test.py --ca backend\certs\ca.crt
```

## Known environment problems (found and fixed / to fix)

1. **Network profile is Public on `HACKATHON-GUEST`** → phones will be blocked. Either run
   this in an **elevated** PowerShell, or use the laptop hotspot:

   ```powershell
   New-NetFirewallRule -DisplayName "Wingman 8443" -Direction Inbound -Protocol TCP `
     -LocalPort 8443 -Action Allow -Profile Private
   Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
   ```

2. **Guest Wi-Fi often has client isolation** (`HACKATHON-GUEST` looks like a guest SSID):
   the phone and laptop will not see each other even with the firewall open. Test with one
   phone's browser on `https://10.10.28.37:8443/`; if it fails, enable **Windows Mobile
   hotspot** and connect all phones to it, then re-run `gen_certs.ps1 -Force` (the hotspot
   subnet `192.168.137.x` will be added to the SAN automatically).

3. **No macOS in the team** ⇒ the two iPhones cannot run a Flutter build from this PC.
   Decide by H2: demo on Android phones (recommended), or borrow a Mac / cloud Mac build.
   The iOS project files exist (`ios/`), so a Mac can build the same repository unchanged.
