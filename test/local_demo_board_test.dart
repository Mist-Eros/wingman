import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/api/api_client.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/state/local_demo_board.dart';
import 'package:wingman/features/dispatcher/demo_tickets.dart';

void main() {
  late LocalDemoBoard board;

  setUp(() {
    board = LocalDemoBoard(
      api: ApiClient(baseUrl: 'https://127.0.0.1:1', token: 'test'),
      seedTickets: buildDemoTickets(),
    );
  });

  tearDown(() => board.dispose());

  Ticket ticketWithCode(String code) =>
      board.tickets.firstWhere((ticket) => ticket.incidentCode == code);

  test('seed has exactly 1 low, 1 medium, 2 high and 1 critical', () {
    final counts = <String, int>{};
    for (final ticket in board.tickets) {
      counts[ticket.urgency.wire] = (counts[ticket.urgency.wire] ?? 0) + 1;
    }
    expect(counts, <String, int>{
      'low': 1,
      'medium': 1,
      'high': 2,
      'critical': 1,
    });
    expect(board.connected, isTrue);
    expect(board.isLocalDemo, isTrue);
  });

  test('low and medium each resolve with one responder', () async {
    for (final code in <String>['OP-OTHER', 'SF-SPILL']) {
      final ticket = ticketWithCode(code);
      expect(
        await board.join(
          ticket.id,
          crewId: 'crew-$code',
          department: ticket.primaryDepartments.first.wire,
        ),
        isTrue,
      );
      expect(await board.vote(ticket.id, crewId: 'crew-$code'), isTrue);
      expect(
        board.find(ticket.id)?.status,
        TicketStatus.resolved,
        reason: '$code should resolve with one responder',
      );
    }
  });

  test('high requires admin confirmation, one responder is enough', () async {
    final ticket = ticketWithCode('SC-BAG');
    expect(ticket.quorum, 1);
    expect(
      await board.join(
        ticket.id,
        crewId: 'security-1',
        department: 'security',
      ),
      isTrue,
    );
    expect(await board.vote(ticket.id, crewId: 'security-1'), isTrue);
    expect(board.find(ticket.id)?.status, TicketStatus.pendingResolution);
    expect(await board.confirmResolution(ticket.id), isTrue);
    expect(board.find(ticket.id)?.status, TicketStatus.resolved);
  });

  test('red SF-FIRE needs two responders + admin confirmation', () async {
    final ticket = ticketWithCode('SF-FIRE');
    expect(ticket.quorum, 2);

    expect(
      await board.join(
        ticket.id,
        crewId: 'fire-1',
        department: 'fire_rescue',
      ),
      isTrue,
    );
    expect(await board.vote(ticket.id, crewId: 'fire-1'), isTrue);
    expect(board.find(ticket.id)?.status, TicketStatus.inProgress);

    expect(
      await board.join(
        ticket.id,
        crewId: 'security-1',
        department: 'security',
      ),
      isTrue,
    );
    expect(await board.vote(ticket.id, crewId: 'security-1'), isTrue);
    expect(board.find(ticket.id)?.status, TicketStatus.pendingResolution);

    expect(await board.confirmResolution(ticket.id), isTrue);
    expect(board.find(ticket.id)?.status, TicketStatus.resolved);
  });

  test('a second responder from the same department is rejected', () async {
    final ticket = ticketWithCode('SC-ITEM');
    expect(
      await board.join(
        ticket.id,
        crewId: 'security-1',
        department: 'security',
      ),
      isTrue,
    );
    expect(
      await board.join(
        ticket.id,
        crewId: 'security-2',
        department: 'security',
      ),
      isFalse,
    );
  });
}
