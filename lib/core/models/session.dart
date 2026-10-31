// =============================================================================
// lib/core/models/session.dart
//
// OWNER: Lead (lib/core/). Defines the three roles and who the current user is.
// The router in `main.dart` is the only place that decides which feature screen
// a role lands on; features read the session via `CoreScope.sessionOf(context)`.
//
// Session now also carries the demo ACCOUNT identity (username) and the
// DEPARTMENT SCOPE: a janitor account is only alerted for terminal incidents, an
// engineer only for technical departments, an admin sees everything. Feature
// screens must filter with `Session.seesDepartments(...)` instead of inventing
// their own rules.
// =============================================================================

import 'dart:convert';

import '../incidents/taxonomy.dart';

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

/// The signed-in demo user. Hackathon auth is intentionally minimal: a hardcoded
/// demo account (see `lib/core/auth/demo_accounts.dart`) + a stable id used for
/// votes/joins. Tokens live in [TokenStore].
class Session {
  const Session({
    required this.role,
    required this.userId,
    required this.displayName,
    this.username = '',
    this.isAdmin = false,
    this.departments = const <Department>{},
  });

  final UserRole role;

  /// Stable id used as `reporter_id`, `crew_id` and `resolve_voter_ids` entry.
  final String userId;

  /// Shown on tickets ("raportat de ..."), dispatcher chips, vote counts.
  final String displayName;

  /// Login handle of the demo account (empty for legacy/demo sessions).
  final String username;

  /// Admin accounts see every department and get the dispatcher dashboard.
  final bool isAdmin;

  /// Department scope for crew accounts. Empty = no restriction (legacy global
  /// accounts); admin ignores it entirely.
  final Set<Department> departments;

  bool get isReporter => role == UserRole.reporter;
  bool get isDispatcher => role == UserRole.dispatcher || isAdmin;
  bool get isCrew => role == UserRole.crew;

  /// The primary department this session responds as on [ticket], if any.
  Department? primaryDepartmentFor(Iterable<Department> primary) {
    if (departments.isEmpty) {
      // Legacy/global crew account: respond as the first required department.
      return primary.isEmpty ? null : primary.first;
    }
    for (final department in primary) {
      if (departments.contains(department)) return department;
    }
    return null;
  }

  /// The single rule for "do I get alerted about this ticket?".
  bool seesDepartments(Iterable<Department> ticketDepartments) {
    if (isAdmin) return true;
    if (departments.isEmpty) return true;
    return ticketDepartments.any(departments.contains);
  }

  /// Human label for the app bar, e.g. "Terminal" / "Mentenanță · IT".
  String get scopeLabel {
    if (isAdmin) return 'Acces total';
    if (departments.isEmpty) return 'Toate';
    return departments.map((department) => department.labelRo).join(' · ');
  }

  /// Builds a throwaway id for the hackathon demo, e.g. `crew-4471`.
  factory Session.demo(UserRole role, {String? displayName}) {
    final suffix = DateTime.now().millisecondsSinceEpoch % 10000;
    final name = displayName?.trim();
    return Session(
      role: role,
      userId: '${role.wire}-$suffix',
      displayName: (name == null || name.isEmpty) ? role.labelRo : name,
    );
  }

  Session copyWith({
    UserRole? role,
    String? userId,
    String? displayName,
    String? username,
    bool? isAdmin,
    Set<Department>? departments,
  }) =>
      Session(
        role: role ?? this.role,
        userId: userId ?? this.userId,
        displayName: displayName ?? this.displayName,
        username: username ?? this.username,
        isAdmin: isAdmin ?? this.isAdmin,
        departments: departments ?? this.departments,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'role': role.wire,
        'user_id': userId,
        'display_name': displayName,
        'username': username,
        'is_admin': isAdmin,
        'departments':
            departments.map((department) => department.wire).toList(),
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    final rawDepartments = json['departments'];
    final departments = <Department>{
      if (rawDepartments is List)
        for (final raw in rawDepartments)
          if (raw is String)
            if (Department.tryFromWire(raw) != null)
              Department.tryFromWire(raw)!,
    };
    return Session(
      role: UserRole.fromWire(json['role'] as String? ?? ''),
      userId: json['user_id'] as String? ?? 'anon',
      displayName: json['display_name'] as String? ?? 'Anonim',
      username: json['username'] as String? ?? '',
      isAdmin: json['is_admin'] == true,
      departments: departments,
    );
  }

  String encode() => jsonEncode(toJson());

  factory Session.decode(String value) =>
      Session.fromJson(jsonDecode(value) as Map<String, dynamic>);

  @override
  String toString() =>
      'Session(${role.wire}, $userId, $displayName, scope=$scopeLabel)';
}
