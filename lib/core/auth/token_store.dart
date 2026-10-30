// =============================================================================
// lib/core/auth/token_store.dart
//
// OWNER: Lead (lib/core/).
//
// Tiny abstraction so `ApiClient` never imports flutter_secure_storage (which
// would force every feature teammate to add the dependency before their code
// builds). Swap in `SecureTokenStore` from `secure_token_store.dart` once the
// package is in pubspec — it is a 3-line change in main.dart.
// =============================================================================

abstract class TokenStore {
  Future<String?> read();

  Future<void> write(String token);

  Future<void> clear();
}

/// Default for the hackathon: the token comes from `--dart-define=API_TOKEN`
/// and lives only in memory. It is NOT persisted, so it cannot leak from a
/// stolen phone; the "strong encryption" story stays in the TLS + short-lived
/// session token.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._token]);

  String? _token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async {
    _token = token;
  }

  @override
  Future<void> clear() async {
    _token = null;
  }
}
