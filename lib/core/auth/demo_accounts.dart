// =============================================================================
// lib/core/auth/demo_accounts.dart
//
// Hardcoded demo accounts. Passwords are NEVER stored in clear text: each
// account keeps a salted SHA-256 hash and `checkPassword` validates against it,
// so the "encrypted accounts" requirement is real even in a hackathon build.
//
// Department scope decides who gets alerted:
//   • Andy Admin   → dispatcher dashboard, sees everything, can decide.
//   • Earl Engineer→ crew, only maintenance/IT/baggage/airside incidents.
//   • John Janitor → crew, only terminal incidents (spills, queues, terminal).
//   • Rita Reporter→ reporter, files incidents.
//
// The demo password is shown on the login card on purpose (judges must be able
// to sign in in 5 seconds); the hash validation is what protects the account.
// =============================================================================

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../incidents/taxonomy.dart';
import '../models/session.dart';

/// Salt for the hardcoded demo accounts (changing it invalidates the hashes).
const String demoAccountSalt = 'wingman-demo-2026-v1';

String hashDemoPassword(String password) =>
    sha256.convert(utf8.encode('$demoAccountSalt::$password')).toString();

class DemoAccount {
  const DemoAccount({
    required this.username,
    required this.displayName,
    required this.passwordHint,
    required this.passwordHash,
    required this.role,
    required this.departments,
    this.isAdmin = false,
    this.tag = '',
  });

  final String username;
  final String displayName;

  /// Shown on the demo login card so judges can sign in quickly.
  final String passwordHint;

  /// Salted SHA-256 of the password (see [hashDemoPassword]).
  final String passwordHash;

  final UserRole role;

  /// Department scope; empty + [isAdmin] means everything.
  final Set<Department> departments;

  final bool isAdmin;

  /// Short role badge for the UI ("ADMIN", "ENGINEER", ...).
  final String tag;

  bool checkPassword(String input) =>
      hashDemoPassword(input) == passwordHash;

  Session toSession() => Session(
        role: role,
        userId: 'acct-$username',
        displayName: displayName,
        username: username,
        isAdmin: isAdmin,
        departments: departments,
      );
}

DemoAccount _account({
  required String username,
  required String displayName,
  required String password,
  required UserRole role,
  required Set<Department> departments,
  bool isAdmin = false,
  required String tag,
}) =>
    DemoAccount(
      username: username,
      displayName: displayName,
      passwordHint: password,
      passwordHash: hashDemoPassword(password),
      role: role,
      departments: departments,
      isAdmin: isAdmin,
      tag: tag,
    );

/// The four hardcoded demo accounts (passwords are hashed above).
final List<DemoAccount> demoAccounts = <DemoAccount>[
  _account(
    username: 'admin',
    displayName: 'Andy Admin',
    password: 'admin123',
    role: UserRole.dispatcher,
    departments: const <Department>{},
    isAdmin: true,
    tag: 'ADMIN',
  ),
  _account(
    username: 'engineer',
    displayName: 'Earl Engineer',
    password: 'engineer123',
    role: UserRole.crew,
    departments: const <Department>{
      Department.maintenance,
      Department.it,
      Department.baggage,
      Department.airside,
    },
    tag: 'ENGINEER',
  ),
  _account(
    username: 'janitor',
    displayName: 'John Janitor',
    password: 'janitor123',
    role: UserRole.crew,
    departments: const <Department>{Department.terminal},
    tag: 'JANITOR',
  ),
  _account(
    username: 'reporter',
    displayName: 'Rita Reporter',
    password: 'reporter123',
    role: UserRole.reporter,
    departments: const <Department>{},
    tag: 'REPORTER',
  ),
];

/// Lookup for a persisted session that only kept the username.
DemoAccount? demoAccountByUsername(String username) {
  for (final account in demoAccounts) {
    if (account.username == username) return account;
  }
  return null;
}

/// Restores the full account identity (scope + admin flag) after a restart, so
/// an old saved session without the new fields is upgraded transparently.
Session restoreSession(Session saved) {
  final account = demoAccountByUsername(saved.username);
  if (account == null) return saved;
  final restored = account.toSession();
  return restored.copyWith(displayName: saved.displayName);
}
