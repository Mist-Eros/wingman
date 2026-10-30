// =============================================================================
// lib/core/models/session.dart
//
// OWNER: Lead (lib/core/). Defines the three roles and who the current user is.
// The router in `main.dart` is the only place that decides which feature screen
// a role lands on; features read the session via `CoreScope.sessionOf(context)`.
// =============================================================================

import 'dart:convert';

enum UserRole {
  reporter('reporter', 'Raportor', '/reporter'),
  dispatcher('dispatcher', 'Dispecer', '/dispatcher'),
  crew('crew', 'Echipaj', '/crew');

  const UserRole(this.wire, this.labelRo, this.route);

  /// snake_case value used at the API boundary (`reporter_id` prefixes etc.).
  final String wire;

  /// Romanian label for the role picker.
  final String labelRo;

  /// Named route handled by `main.dart`.
  final String route;

  static UserRole fromWire(String value) {
    for (final role in UserRole.values) {
      if (role.wire == value.trim().toLowerCase()) return role;
    }
    throw FormatException('Unknown UserRole "$value"');
  }
}

/// The signed-in demo user. Hackathon auth is intentionally minimal: role +
/// display name + an id used for votes/joins. Tokens live in [TokenStore].
class Session {
  const Session({
    required this.role,
    required this.userId,
    required this.displayName,
  });

  final UserRole role;

  /// Stable id used as `reporter_id`, `crew_id` and `resolve_voter_ids` entry.
  final String userId;

  /// Shown on tickets ("raportat de ..."), dispatcher chips, vote counts.
  final String displayName;

  bool get isReporter => role == UserRole.reporter;
  bool get isDispatcher => role == UserRole.dispatcher;
  bool get isCrew => role == UserRole.crew;

  /// Builds a throwaway id for the hackathon demo, e.g. `crew-4471`.
  factory Session.demo(UserRole role, {String? displayName}) {
    final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
    final name = displayName?.trim();
    return Session(
      role: role,
      userId: '${role.wire}-$suffix',
      displayName: (name == null || name.isEmpty) ? '${role.labelRo} demo' : name,
    );
  }

  Session copyWith({UserRole? role, String? userId, String? displayName}) =>
      Session(
        role: role ?? this.role,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role.wire,
        'user_id': userId,
        'display_name': displayName,
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        role: UserRole.fromWire(json['role'] as String? ?? ''),
        userId: json['user_id'] as String? ?? 'anon',
        displayName: json['display_name'] as String? ?? 'Anonim',
      );

  String encode() => jsonEncode(toJson());

  factory Session.decode(String value) =>
      Session.fromJson(jsonDecode(value) as Map<String, dynamic>);

  @override
  String toString() => 'Session(${role.wire}, $userId, $displayName)';
}
