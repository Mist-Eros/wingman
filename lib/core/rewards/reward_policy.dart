// =============================================================================
// lib/core/rewards/reward_policy.dart
//
// Rewards are a feature module with a pure, testable policy:
//
//   tickets + crew id + RewardRules  ->  RewardLedger
//
// The Account screen only renders the ledger. Changing points, adding badges or
// replacing the whole reward scheme does not touch account UI or ticket code.
// =============================================================================

import '../../core/models/ticket.dart';

class RewardRules {
  const RewardRules({
    this.attendedPoints = 2,
    this.resolvedBonus = 10,
    this.deniedPoints = 0,
    this.pointsLabel = 'PUNCTE',
  });

  /// Points for taking/attending a ticket.
  final int attendedPoints;

  /// Extra points when that ticket is resolved.
  final int resolvedBonus;

  /// Points for an attended ticket that was denied (usually 0).
  final int deniedPoints;

  /// Label shown in the account header (configurable per application).
  final String pointsLabel;
}

class RewardEntry {
  const RewardEntry({
    required this.ticket,
    required this.points,
    required this.reason,
  });

  final Ticket ticket;
  final int points;

  /// Short machine key (`attended`, `resolved_bonus`, `denied`) so a UI can
  /// localise the copy without parsing strings.
  final String reason;
}

class RewardLedger {
  const RewardLedger({
    required this.entries,
    required this.totalPoints,
    required this.attendedCount,
    required this.resolvedCount,
  });

  final List<RewardEntry> entries;
  final int totalPoints;
  final int attendedCount;
  final int resolvedCount;

  int get inProgressCount => attendedCount - resolvedCount;
  bool get isEmpty => entries.isEmpty;
}

abstract interface class RewardPolicy {
  RewardLedger ledgerFor({
    required String crewId,
    required Iterable<Ticket> tickets,
  });
}

class RuleBasedRewardPolicy implements RewardPolicy {
  const RuleBasedRewardPolicy({this.rules = const RewardRules()});

  final RewardRules rules;

  @override
  RewardLedger ledgerFor({
    required String crewId,
    required Iterable<Ticket> tickets,
  }) {
    final attended = tickets
        .where((ticket) => ticket.joinedCrewIds.contains(crewId))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final entries = <RewardEntry>[];
    var total = 0;
    var resolved = 0;

    for (final ticket in attended) {
      var points = rules.attendedPoints;
      var reason = 'attended';
      switch (ticket.status) {
        case TicketStatus.resolved:
          points += rules.resolvedBonus;
          reason = 'resolved';
          resolved++;
        case TicketStatus.denied:
          points += rules.deniedPoints;
          reason = 'denied';
        default:
          break;
      }
      total += points;
      entries.add(RewardEntry(ticket: ticket, points: points, reason: reason));
    }

    return RewardLedger(
      entries: entries,
      totalPoints: total,
      attendedCount: entries.length,
      resolvedCount: resolved,
    );
  }
}
