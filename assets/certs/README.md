# assets/certs

`ca.crt` is **generated**, not handwritten. From the repo root:

```powershell
.\scripts\gen_certs.ps1 -Force
```

The script creates:

* `backend/certs/ca.key`, `ca.crt`, `server.key`, `server.csr`, `server.crt`, `san.cnf`
  (private keys — never commit these; `backend/certs/` is git-ignored)
* `assets/certs/ca.crt` — a copy of the **public** CA certificate bundled into the app so
  `dart:io` accepts the self-signed server certificate (`lib/core/api/api_client.dart`
  pins it through `SecurityContext.setTrustedCertificatesBytes`).

Commit `assets/certs/ca.crt` after generating it: every teammate's build must trust the same
CA. Do **not** commit `ca.key` or `server.key`.

`pubspec.yaml` must declare the asset:

```yaml
flutter:
  assets:
    - assets/certs/ca.crt
```

If this folder contains only this README, the asset is missing — run the script above, then
`flutter pub get`. Phone-side profile installation is described in
[docs/certs-and-phones.md](../../docs/certs-and-phones.md).
