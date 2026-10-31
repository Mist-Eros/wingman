import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/rewards/reward_policy.dart';

Ticket _ticket({
  required String id,
  required TicketStatus status,
  required List<String> joinedCrewIds,
  DateTime? updatedAt,
  String reporterId = 'reporter-1',
  String urgency = 'critical',
  List<String> voterIds = const <String>[],
}) {
  final now = (updatedAt ?? DateTime.utc(2026, 1, 1, 12)).toUtc();
  return Ticket.fromJson(<String, dynamic>{
    'id': id,
    'incident_code': 'SF-FIRE',
    'label_ro': 'Foc sau fum în terminal',
    'category': 'safety_fire',
    'urgency': urgency,
    'status': status.wire,
    'source': 'voice',
    'reporter_id': reporterId,
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
    'resolve_voter_ids': voterIds,
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
          reportPoints: 2,
          attendedPoints: 0,
          resolvedBonus: 5,
          deniedPoints: 0,
        ),
      );
      final ledger = policy.ledgerFor(crewId: 'crew-1', tickets: tickets);

      expect(
          ledger.totalPoints, 5); // 5 for joined + solved, 0 for pending/denied
      expect(ledger.entries[0].points, 5);
      expect(ledger.entries[0].reason, 'joined_solved');
      expect(ledger.entries[1].points, 0);
      expect(ledger.entries[2].points, 0);
      expect(ledger.entries[2].reason, 'joined_pending');
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

      expect(ledger.totalPoints, 8); // (5) + (3) + 0 pending
    });

    test('reporting alone earns report points', () {
      final ledger = const RuleBasedRewardPolicy().ledgerFor(
        crewId: 'crew-1',
        tickets: <Ticket>[
          _ticket(
            id: 'my-report',
            status: TicketStatus.dispatched,
            joinedCrewIds: const <String>[],
            reporterId: 'crew-1',
            urgency: 'low',
          ),
        ],
      );
      expect(ledger.reportedCount, 1);
      expect(ledger.attendedCount, 0);
      expect(ledger.totalPoints, 2);
    });

    test('self-report + self-resolve alone is blocked when not dangerous', () {
      final ledger = const RuleBasedRewardPolicy().ledgerFor(
        crewId: 'crew-1',
        tickets: <Ticket>[
          _ticket(
            id: 'farm',
            status: TicketStatus.resolved,
            joinedCrewIds: const <String>['crew-1'],
            reporterId: 'crew-1',
            urgency: 'low',
            voterIds: const <String>['crew-1'],
          ),
        ],
      );
      expect(ledger.totalPoints, 0);
      expect(ledger.blockedSelfResolutions, 1);
      expect(ledger.entries.single.reason, 'self_resolution_blocked');
    });

    test('self-report + self-resolve is allowed for a dangerous incident', () {
      final ledger = const RuleBasedRewardPolicy().ledgerFor(
        crewId: 'crew-1',
        tickets: <Ticket>[
          _ticket(
            id: 'danger',
            status: TicketStatus.resolved,
            joinedCrewIds: const <String>['crew-1'],
            reporterId: 'crew-1',
            urgency: 'critical',
            voterIds: const <String>['crew-1'],
          ),
        ],
      );
      expect(ledger.totalPoints, 7); // 2 report + 5 joined & solved
      expect(ledger.blockedSelfResolutions, 0);
    });

    test('a reporter-only ticket resolved by someone else gets only 2 points',
        () {
      final ledger = const RuleBasedRewardPolicy().ledgerFor(
        crewId: 'crew-1',
        tickets: <Ticket>[
          _ticket(
            id: 'reported-elsewhere',
            status: TicketStatus.resolved,
            joinedCrewIds: const <String>['crew-2'],
            reporterId: 'crew-1',
            urgency: 'low',
          ),
        ],
      );
      expect(ledger.totalPoints, 2);
      expect(ledger.resolvedCount, 0);
      expect(ledger.entries.single.reason, 'reported+reported_only');
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
