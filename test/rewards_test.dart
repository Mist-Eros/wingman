import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/rewards/reward_policy.dart';

Ticket _ticket({
  required String id,
  required TicketStatus status,
  required List<String> joinedCrewIds,
  DateTime? updatedAt,
}) {
  final now = (updatedAt ?? DateTime.utc(2026, 1, 1, 12)).toUtc();
  return Ticket.fromJson(<String, dynamic>{
    'id': id,
    'incident_code': 'SF-FIRE',
    'label_ro': 'Foc sau fum în terminal',
    'category': 'safety_fire',
    'urgency': 'critical',
    'status': status.wire,
    'source': 'voice',
    'reporter_id': 'reporter-1',
    'reporter_name': 'Reporter',
    'transcript': 'fum',
    'photo_base64': null,
    'location': <String, dynamic>{
      'terminal': 'T1',
      'zone': 'Poarta 12',
      'lat': null,
      'lng': null,
      'note': null,
    },
    'confidence': 0.9,
    'ai_source': 'fallback',
    'ai_rationale': null,
    'primary_departments': <String>['fire_rescue'],
    'standby_departments': <String>[],
    'joined_crew_ids': joinedCrewIds,
    'resolve_votes': 0,
    'resolve_voter_ids': <String>[],
    'quorum': 1,
    'override_deadline': null,
    'dispatched_at': now.toIso8601String(),
    'resolved_at':
        status == TicketStatus.resolved ? now.toIso8601String() : null,
    'resolution_note': null,
    'decided_by': null,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
    'version': 1,
  });
}

void main() {
  group('RuleBasedRewardPolicy', () {
    final tickets = <Ticket>[
      _ticket(
        id: 'resolved',
        status: TicketStatus.resolved,
        joinedCrewIds: const <String>['crew-1'],
        updatedAt: DateTime.utc(2026, 1, 1, 12),
      ),
      _ticket(
        id: 'denied',
        status: TicketStatus.denied,
        joinedCrewIds: const <String>['crew-1'],
        updatedAt: DateTime.utc(2026, 1, 1, 11),
      ),
      _ticket(
        id: 'active',
        status: TicketStatus.inProgress,
        joinedCrewIds: const <String>['crew-1'],
        updatedAt: DateTime.utc(2026, 1, 1, 10),
      ),
      _ticket(
        id: 'other-crew',
        status: TicketStatus.resolved,
        joinedCrewIds: const <String>['crew-2'],
      ),
    ];

    test('creates one entry per attended ticket, newest first', () {
      const policy = RuleBasedRewardPolicy();
      final ledger = policy.ledgerFor(crewId: 'crew-1', tickets: tickets);

      expect(ledger.entries.map((entry) => entry.ticket.id), <String>[
        'resolved',
        'denied',
        'active',
      ]);
      expect(ledger.attendedCount, 3);
      expect(ledger.resolvedCount, 1);
      expect(ledger.inProgressCount, 2);
    });

    test('applies join + resolved bonus + denied rules', () {
      const policy = RuleBasedRewardPolicy(
        rules: RewardRules(
          attendedPoints: 2,
          resolvedBonus: 10,
          deniedPoints: 0,
        ),
      );
      final ledger = policy.ledgerFor(crewId: 'crew-1', tickets: tickets);

      expect(ledger.totalPoints, 16); // 12 + 2 + 2
      expect(ledger.entries[0].points, 12);
      expect(ledger.entries[0].reason, 'resolved');
      expect(ledger.entries[1].points, 2);
      expect(ledger.entries[2].points, 2);
    });

    test('different rules can be injected without touching UI', () {
      const policy = RuleBasedRewardPolicy(
        rules: RewardRules(
          attendedPoints: 1,
          resolvedBonus: 5,
          deniedPoints: 3,
          pointsLabel: 'CREDITE',
        ),
      );
      final ledger = policy.ledgerFor(crewId: 'crew-1', tickets: tickets);

      expect(ledger.totalPoints, 11); // (1+5) + (1+3) + 1
    });

    test('users who attended nothing get an empty ledger', () {
      const policy = RuleBasedRewardPolicy();
      final ledger = policy.ledgerFor(
        crewId: 'nobody',
        tickets: tickets,
      );

      expect(ledger.isEmpty, isTrue);
      expect(ledger.totalPoints, 0);
      expect(ledger.attendedCount, 0);
    });
  });
}
