// Widget tests for the Crew UI — no phone, no backend.
// Run:  flutter test test/crew_screen_test.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/api/api_client.dart';
import 'package:wingman/core/auth/token_store.dart';
import 'package:wingman/core/core_scope.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/session.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/state/ticket_board.dart';
import 'package:wingman/features/crew/crew_screen.dart';

Ticket _sampleTicket({
  String id = 'ticket-1',
  TicketStatus status = TicketStatus.dispatched,
  List<String> joined = const <String>[],
  int resolveVotes = 0,
  List<String> voters = const <String>[],
  int quorum = 2,
  int version = 1,
}) {
  final now = DateTime.utc(2026, 10, 30, 9);
  return Ticket(
    id: id,
    incidentCode: 'SF-FIRE',
    labelRo: 'Foc sau fum în terminal',
    category: IncidentCategory.safetyFire,
    urgency: Urgency.critical,
    status: status,
    source: ReportSource.voice,
    reporterId: 'reporter-1',
    reporterName: 'Andrei P.',
    transcript: 'Este fum lângă poarta 12.',
    location: const IncidentLocation(terminal: 'T1', zone: 'Poarta 12'),
    confidence: 0.93,
    aiSource: AiSource.ollama,
    primaryDepartments: const <Department>[
      Department.fireRescue,
      Department.security,
    ],
    standbyDepartments: const <Department>[Department.operations],
    createdAt: now,
    updatedAt: now,
    joinedCrewIds: joined,
    resolveVotes: resolveVotes,
    resolveVoterIds: voters,
    quorum: quorum,
    version: version,
  );
}

/// In-memory API so TicketBoard.join/vote work offline.
class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'https://fake.test', allowInsecure: true);

  final Map<String, Ticket> store = <String, Ticket>{};
  final StreamController<ServerEvent> events =
      StreamController<ServerEvent>.broadcast();

  void seed(Ticket ticket) => store[ticket.id] = ticket;

  @override
  Future<List<Ticket>> listTickets({TicketStatus? status}) async {
    final all = store.values.toList(growable: false);
    if (status == null) return all;
    return all.where((t) => t.status == status).toList(growable: false);
  }

  @override
  Future<Ticket> join(
    String ticketId, {
    required String crewId,
    required String department,
    String? crewName,
  }) async {
    final current = store[ticketId];
    if (current == null) {
      throw ApiException('Ticket $ticketId not found', statusCode: 404);
    }
    if (current.isJoinedBy(crewId)) return current;
    final updated = current.copyWith(
      joinedCrewIds: <String>[...current.joinedCrewIds, crewId],
      joinedDepartments: <String>[...current.joinedDepartments, department],
      status: TicketStatus.inProgress,
      version: current.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    store[ticketId] = updated;
    return updated;
  }

  @override
  Future<Ticket> vote(
    String ticketId, {
    required String crewId,
    bool approve = true,
  }) async {
    final current = store[ticketId];
    if (current == null) {
      throw ApiException('Ticket $ticketId not found', statusCode: 404);
    }
    if (current.hasVotedBy(crewId)) return current;
    final votes = current.resolveVotes + (approve ? 1 : 0);
    final voters = <String>[...current.resolveVoterIds, crewId];
    final resolved = approve && votes >= current.quorum;
    final updated = current.copyWith(
      resolveVotes: votes,
      resolveVoterIds: voters,
      status: resolved ? TicketStatus.resolved : current.status,
      version: current.version + 1,
      updatedAt: DateTime.now().toUtc(),
    );
    store[ticketId] = updated;
    return updated;
  }

  @override
  Stream<ServerEvent> connectEvents() => events.stream;
}

Widget _harness({
  required _FakeApi api,
  required TicketBoard board,
  Session? session,
}) {
  return MaterialApp(
    home: CoreScope(
      api: api,
      board: board,
      tokenStore: MemoryTokenStore('demo-token'),
      session: session ??
          const Session(
            role: UserRole.crew,
            userId: 'crew-1',
            displayName: 'Echipaj Test',
          ),
      onSignOut: () {},
      child: const CrewScreen(),
    ),
  );
}

void main() {
  late _FakeApi api;
  late TicketBoard board;

  setUp(() {
    api = _FakeApi();
    board = TicketBoard(api: api);
    board.applyEvent(ServerEvent.connection(true));
  });

  tearDown(() async {
    board.dispose();
    await api.events.close();
  });

  testWidgets('empty state when no dispatched tickets', (tester) async {
    await tester.pumpWidget(_harness(api: api, board: board));
    await tester.pumpAndSettle();

    expect(find.text('Echipaj'), findsOneWidget);
    expect(find.textContaining('Echipaj Test'), findsOneWidget);
    expect(find.text('WSS: conectat'), findsOneWidget);
    expect(find.text('Nicio intervenție alocată'), findsOneWidget);
    expect(find.text('Preia'), findsNothing);
  });

  testWidgets('lists dispatched ticket and shows Preia', (tester) async {
    final ticket = _sampleTicket();
    api.seed(ticket);
    board.applyEvent(
      ServerEvent(type: ServerEvent.typeTicketCreated, ticket: ticket),
    );

    await tester.pumpWidget(_harness(api: api, board: board));
    await tester.pumpAndSettle();

    expect(find.text('SF-FIRE'), findsOneWidget);
    expect(find.text('Foc sau fum în terminal'), findsOneWidget);
    expect(find.textContaining('Poarta 12'), findsWidgets);
    expect(find.text('Preia'), findsOneWidget);
    expect(find.textContaining('Voturi: 0/2'), findsOneWidget);
  });

  testWidgets('Preia joins then enables Rezolvat', (tester) async {
    final ticket = _sampleTicket();
    api.seed(ticket);
    board.applyEvent(
      ServerEvent(type: ServerEvent.typeTicketCreated, ticket: ticket),
    );

    await tester.pumpWidget(_harness(api: api, board: board));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Preia'));
    await tester.pumpAndSettle();

    expect(board.find('ticket-1')!.isJoinedBy('crew-1'), isTrue);
    expect(find.text('Preia'), findsNothing);
    expect(find.text('Rezolvat'), findsWidgets);
    expect(find.textContaining('1 membru alăturat'), findsOneWidget);
  });

  testWidgets('two votes reach quorum and show resolved snackbar',
      (tester) async {
    final ticket = _sampleTicket(
      status: TicketStatus.inProgress,
      joined: const <String>['crew-1', 'crew-2'],
      resolveVotes: 1,
      voters: const <String>['crew-2'],
      quorum: 2,
    );
    api.seed(ticket);
    board.applyEvent(
      ServerEvent(type: ServerEvent.typeTicketUpdated, ticket: ticket),
    );

    await tester.pumpWidget(_harness(api: api, board: board));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rezolvat').first);
    await tester.pumpAndSettle();

    expect(board.find('ticket-1')!.status, TicketStatus.resolved);
    expect(find.textContaining('Intervenție rezolvată'), findsOneWidget);
    expect(find.text('SF-FIRE'), findsNothing);
  });
}
