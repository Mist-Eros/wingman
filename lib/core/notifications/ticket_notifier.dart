// =============================================================================
// lib/core/notifications/ticket_notifier.dart
//
// ANYONE can report an incident; only the departments the incident needs get a
// notification. The rule (single source of truth for alerts):
//
//   a ticket alerts a session  ⇔  the ticket is active
//                              AND the ticket's PRIMARY departments intersect
//                                  that session's department scope.
//
// Example: a fuel leak at gate 5 is classified SF-SPILL, primary departments
// [maintenance, terminal] → the engineer (maintenance) AND the janitor
// (terminal) both get alerted; a security-only incident does not ping either.
//
// The pure policy lives in [TicketAlertPolicy] so it is unit-testable without
// the plugin. [TicketNotifier] shows the Android/iOS notification.
// =============================================================================

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/session.dart';
import '../models/ticket.dart';

/// Configurable rules for who should receive alerts. The active DomainConfig
/// maps its `notifications.roles` list into these rule flags.
class TicketAlertRules {
  const TicketAlertRules({
    this.roles = const <String>{'crew', 'dispatcher'},
  });

  final Set<String> roles;

  bool wants(Session session) {
    if (session.role == UserRole.crew) return roles.contains('crew');
    if (session.isAdmin) return roles.contains('dispatcher');
    return false;
  }
}

/// Pure alerting policy: no plugin, no I/O — easy to test.
class TicketAlertPolicy {
  TicketAlertPolicy({this.rules = const TicketAlertRules()});

  final TicketAlertRules rules;
  final Set<String> _seen = <String>{};

  /// Remember current tickets without alerting (called after the first
  /// snapshot / after sign-in so old tickets don't buzz the phone).
  void seed(Iterable<Ticket> tickets) {
    for (final ticket in tickets) {
      _seen.add(ticket.id);
    }
  }

  /// Tickets that should alert [session] now (new ids only, matching scope).
  List<Ticket> alertsFor({
    required Iterable<Ticket> tickets,
    required Session session,
  }) {
    if (!rules.wants(session)) return const <Ticket>[];
    final alerts = <Ticket>[];
    for (final ticket in tickets) {
      if (!_seen.add(ticket.id)) continue; // already seen
      if (!_isActive(ticket.status)) continue;
      if (!session.seesDepartments(ticket.primaryDepartments)) continue;
      alerts.add(ticket);
    }
    return alerts;
  }

  /// Reporters don't receive alerts; crew and dispatchers do.
  /// Kept static for tests/legacy callers; the instance reads [rules].
  static bool wantsAlerts(Session session) =>
      session.role == UserRole.crew || session.isAdmin;

  static bool _isActive(TicketStatus status) =>
      status == TicketStatus.dispatched ||
      status == TicketStatus.pendingOverride;

  /// Forget what was already alerted (call on sign-out / account switch).
  void clear() => _seen.clear();
}

/// Thin wrapper around flutter_local_notifications.
class TicketNotifier {
  TicketNotifier({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  bool get ready => _ready;

  Future<void> init() async {
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _plugin.initialize(settings);
    _ready = true;
  }

  Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> showTicket(Ticket ticket) async {
    if (!_ready) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'wingman_incidents',
        'Incidente Wingman',
        channelDescription: 'Alerte pentru incidentele din departamentul tău',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        ticker: 'Incident nou',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    final where = ticket.location.display.isEmpty
        ? 'Locație nespecificată'
        : ticket.location.display;
    final departments =
        ticket.primaryDepartments.map((d) => d.labelRo).join(' · ');
    await _plugin.show(
      ticket.id.hashCode,
      '🚨 ${ticket.incidentCode} · ${ticket.labelRo}',
      '$where · $departments',
      details,
    );
  }
}
