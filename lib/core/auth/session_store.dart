// =============================================================================
// lib/core/auth/session_store.dart
//
// OWNER: Lead (lib/core/).
//
// Persists the demo `Session` (role + stable user id + display name) so the app
// remembers who you are across restarts. Without this, killing the app gave you
// a brand-new `crew-XXXX` id, and a ticket you had already joined looked
// "unjoined" again (server still had the old id) — a confusing demo behaviour.
//
// Mirrors `token_store.dart`: a `Memory…` implementation for tests and a
// `Secure…` one backed by flutter_secure_storage for the device. Writes never
// throw: the demo must keep working even if the platform store is unavailable.
// =============================================================================

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/session.dart';

abstract interface class SessionStore {
  Future<Session?> read();
  Future<void> write(Session session);
  Future<void> clear();
}

/// In-memory implementation (tests, or a platform without a keystore).
class MemorySessionStore implements SessionStore {
  Session? _session;

  @override
  Future<Session?> read() async => _session;

  @override
  Future<void> write(Session session) async => _session = session;

  @override
  Future<void> clear() async => _session = null;
}

/// Keychain/Keystore-backed implementation used by `main.dart`.
class SecureSessionStore implements SessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  static const String _key = 'wingman_session_v1';

  final FlutterSecureStorage _storage;

  @override
  Future<Session?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return Session.decode(raw);
    } on Object catch (error) {
      debugPrint('[session] read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(Session session) async {
    try {
      await _storage.write(key: _key, value: session.encode());
    } on Object catch (error) {
      debugPrint('[session] write failed: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _key);
    } on Object catch (error) {
      debugPrint('[session] clear failed: $error');
    }
  }
}
