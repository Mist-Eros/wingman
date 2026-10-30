// Anyone can report; only the departments an incident needs get an alert.
// This locks in the routing rule the demo depends on:
//   fuel leak (SF-SPILL, primary maintenance+terminal) -> engineer AND janitor.
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/session.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/notifications/ticket_notifier.dart';

Session _crew(Set<Department> departments) => Session(
      role: UserRole.crew,
      userId: 'crew-test',
      displayName: 'Test Crew',
      departments: departments,
    );

Ticket _ticket({
  required String id,
  required String code,
  TicketStatus status = TicketStatus.dispatched,
}) {
  final type = IncidentTaxonomy.byCode(code)!;
  return Ticket(
    id: id,
    incidentCode: type.code,
    labelRo: type.labelRo,
    category: type.category,
    urgency: type.urgency,
    status: status,
    source: ReportSource.voice,
    reporterId: 'reporter-1',
    reporterName: 'Reporter',
    transcript: 'test',
    location: const IncidentLocation(terminal: 'T1', zone: 'Poarta 5'),
    confidence: 0.9,
    aiSource: AiSource.ollama,
    primaryDepartments: type.primaryDepartments,
    standbyDepartments: type.standbyDepartments,
    createdAt: DateTime.now().toUtc(),
    updatedAt: DateTime.now().toUtc(),
  );
}

void main() {
  test('fuel leak alerts both engineer and janitor, not security-only', () {
    final ticket = _ticket(id: 't-spill', code: 'SF-SPILL');
    final engineer = _crew(<Department>{Department.maintenance, Department.it});
    final janitor = _crew(<Department>{Department.terminal});
    final security = _crew(<Department>{Department.security});

    final engineerPolicy = TicketAlertPolicy();
    expect(
      engineerPolicy.alertsFor(tickets: <Ticket>[ticket], session: engineer),
      hasLength(1),
    );
    final janitorPolicy = TicketAlertPolicy();
    expect(
      janitorPolicy.alertsFor(tickets: <Ticket>[ticket], session: janitor),
      hasLength(1),
    );
    final securityPolicy = TicketAlertPolicy();
    expect(
      securityPolicy.alertsFor(tickets: <Ticket>[ticket], session: security),
      isEmpty,
    );
  });

  test('only active tickets alert, and only once', () {
    final policy = TicketAlertPolicy();
    final resolved = _ticket(
      id: 't-resolved',
      code: 'SF-SPILL',
      status: TicketStatus.resolved,
    );
    final active = _ticket(id: 't-active', code: 'SF-SPILL');
    final janitor = _crew(<Department>{Department.terminal});

    expect(
      policy.alertsFor(tickets: <Ticket>[resolved], session: janitor),
      isEmpty,
    );
    expect(
      policy.alertsFor(tickets: <Ticket>[active], session: janitor),
      hasLength(1),
    );
    // Already seen → no duplicate notification for the same ticket id.
    expect(
      policy.alertsFor(tickets: <Ticket>[active], session: janitor),
      isEmpty,
    );
  });

  test('reporters do not receive alerts', () {
    final reporter = Session.demo(UserRole.reporter, displayName: 'Rita');
    expect(TicketAlertPolicy.wantsAlerts(reporter), isFalse);
    expect(
      TicketAlertPolicy().alertsFor(
        tickets: <Ticket>[_ticket(id: 't1', code: 'SF-SPILL')],
        session: reporter,
      ),
      isEmpty,
    );
  });

  test('admin/dispatcher receives everything (sees all)', () {
    final admin = Session(
      role: UserRole.dispatcher,
      userId: 'admin',
      displayName: 'Andy Admin',
      isAdmin: true,
    );
    expect(TicketAlertPolicy.wantsAlerts(admin), isTrue);
    expect(
      TicketAlertPolicy().alertsFor(
        tickets: <Ticket>[_ticket(id: 't-fire', code: 'SF-FIRE')],
        session: admin,
      ),
      hasLength(1),
    );
  });
}
