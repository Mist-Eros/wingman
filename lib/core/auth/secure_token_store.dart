// =============================================================================
// lib/core/auth/secure_token_store.dart
//
// OWNER: Lead (lib/core/).
//
// ⚠️  REQUIRES `flutter_secure_storage` IN pubspec.yaml. That is why `main.dart`
//     ships with `MemoryTokenStore` and why this file is not imported anywhere
//     by default: the app must build on hour 0, before anyone edits pubspec.
//
// To enable (2 minutes):
//   1. pubspec.yaml → dependencies:
//        flutter_secure_storage: ^9.2.2   # or whatever pub resolves
//   2. flutter pub get
//   3. main.dart → replace the MemoryTokenStore line with:
//        final tokenStore = SecureTokenStore(fallback: kApiToken);
//      and `import 'core/auth/secure_token_store.dart';`
//
// Storage key is hardcoded; the value is the demo API token. iOS keeps it in
// the Keychain, Android in EncryptedSharedPreferences (AES-256, Android Keystore
// backed).
// =============================================================================

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'token_store.dart';

class SecureTokenStore implements TokenStore {
  SecureTokenStore({
    FlutterSecureStorage? storage,
    String? fallback,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _fallback = fallback;

  static const String _key = 'wingman_api_token';

  final FlutterSecureStorage _storage;

  /// Used only when the platform store is unavailable (emulator without
  /// keystore, web preview, etc.) so the demo never hard-fails.
  final String? _fallback;

  @override
  Future<String?> read() async {
    try {
      final stored = await _storage.read(key: _key);
      if (stored != null && stored.isNotEmpty) return stored;
    } on Object {
      // fall through to fallback
    }
    return _fallback;
  }

  @override
  Future<void> write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
    } on Object {
      // Demo must keep running; the token is also passed via --dart-define.
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object {
      // ignore
    }
  }
}
