// The single rule for who is called to an incident.
//
// A job is routed by its PRIMARY departments. Standby departments see the
// ticket but must not be woken up or put in their active queue. Keeping this in
// one place prevents the crew queue and local notifications from drifting.

import '../incidents/taxonomy.dart';
import '../models/session.dart';
import '../models/ticket.dart';

abstract final class TicketTargeting {
  static Set<Department> required(Ticket ticket) =>
      ticket.primaryDepartments.toSet();

  /// True when [session] must be called/alerted for [ticket].
  static bool isCalled({required Ticket ticket, required Session session}) {
    if (session.isAdmin) return true;
    // Legacy/global crew account with no scope still receives everything.
    if (session.departments.isEmpty) return true;
    return ticket.primaryDepartments.any(session.departments.contains);
  }

  /// Human list for cards/notifications: "Pompieri / Salvare · Medical".
  static String requiredLabel(Ticket ticket) =>
      ticket.primaryDepartments.map((department) => department.labelRo).join(
            ' · ',
          );

  static String? standbyLabel(Ticket ticket) {
    if (ticket.standbyDepartments.isEmpty) return null;
    return ticket.standbyDepartments
        .map((department) => department.labelRo)
        .join(' · ');
  }
}
