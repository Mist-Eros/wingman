import 'dart:math';

import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';

/// Local demo data for UI work before the mobile/backend link is live.
/// Uses real [Ticket] models from core â€” never invents parallel types.
List<Ticket> buildDemoTickets({DateTime? now}) {
  final n = (now ?? DateTime.now()).toUtc();

  Ticket fromType({
    required String id,
    required String code,
    required Urgency urgency,
    required TicketStatus status,
    required double confidence,
    required String transcript,
    required String locationZone,
    required String reporterName,
    String? aiRationale,
    String terminal = 'T1',
    List<String> joined = const <String>[],
    int resolveVotes = 0,
    DateTime? overrideDeadline,
    DateTime? createdAt,
    String? decidedBy,
  }) {
    final type = IncidentTaxonomy.all.firstWhere((t) => t.code == code);
    final created =
        createdAt ?? n.subtract(Duration(minutes: id.hashCode.abs() % 18 + 1));
    return Ticket(
      id: id,
      incidentCode: type.code,
      labelRo: type.labelRo,
      category: type.category,
      urgency: urgency,
      status: status,
      source: ReportSource.voice,
      reporterId: 'reporter-demo',
      reporterName: reporterName,
      transcript: transcript,
      location: IncidentLocation(terminal: terminal, zone: locationZone),
      confidence: confidence,
      aiSource: confidence < 0.65 ? AiSource.fallback : AiSource.ollama,
      aiRationale: aiRationale,
      primaryDepartments: type.primaryDepartments,
      standbyDepartments: type.standbyDepartments,
      joinedCrewIds: joined,
      resolveVotes: resolveVotes,
      quorum: max(
        1,
        IncidentTaxonomy.byCode(code)?.primaryDepartments.length ?? 1,
      ),
      overrideDeadline: overrideDeadline,
      decidedBy: decidedBy,
      createdAt: created,
      updatedAt: created,
      version: 1,
    );
  }

  return <Ticket>[
    fromType(
      id: 'demo-low-01',
      code: 'OP-OTHER',
      urgency: Urgency.low,
      status: TicketStatus.dispatched,
      confidence: 0.55,
      transcript: 'Coada de la control este lungă, dar nu e nimic periculos.',
      locationZone: 'Control securitate',
      reporterName: 'Andrei P.',
      aiRationale: 'Aglomerare operationala fara risc imediat.',
      createdAt: n.subtract(const Duration(minutes: 3)),
    ),
    fromType(
      id: 'demo-med-02',
      code: 'SF-SPILL',
      urgency: Urgency.medium,
      status: TicketStatus.dispatched,
      confidence: 0.86,
      transcript: 'S-a vărsat un lichid pe jos lângă poarta 3.',
      locationZone: 'Poarta 3',
      reporterName: 'Ioana M.',
      aiRationale: 'Scurgere in terminal, risc de alunecare.',
      createdAt: n.subtract(const Duration(minutes: 7)),
    ),
    fromType(
      id: 'demo-high-03',
      code: 'SC-BAG',
      urgency: Urgency.high,
      status: TicketStatus.dispatched,
      confidence: 0.93,
      transcript: 'Bagaj fără proprietar lângă banda de bagaje 3.',
      locationZone: 'Banda bagaje 3',
      reporterName: 'Mihai D.',
      terminal: 'T2',
      aiRationale: 'Bagaj nesupravegheat, verificare securitate.',
      createdAt: n.subtract(const Duration(minutes: 11)),
    ),
    fromType(
      id: 'demo-high-04',
      code: 'MT-BELT',
      urgency: Urgency.high,
      status: TicketStatus.dispatched,
      confidence: 0.88,
      transcript: 'Defecțiune la banda transportoare de bagaje.',
      locationZone: 'Check-in zona B',
      reporterName: 'Elena V.',
      terminal: 'T2',
      aiRationale: 'Banda de bagaje oprita, mentenanta necesara.',
      createdAt: n.subtract(const Duration(minutes: 15)),
    ),
    fromType(
      id: 'demo-crit-05',
      code: 'SF-FIRE',
      urgency: Urgency.critical,
      status: TicketStatus.dispatched,
      confidence: 0.96,
      transcript: 'Fum dens lângă poarta 12, în terminalul 1.',
      locationZone: 'Poarta 12',
      reporterName: 'Furtuna-Cola Andrei-Alexandru',
      aiRationale: 'Fum in terminal, posibil incendiu.',
      createdAt: n.subtract(const Duration(minutes: 20)),
    ),
  ];
}

bool isDemoTicketId(String id) => id.startsWith('demo-');
