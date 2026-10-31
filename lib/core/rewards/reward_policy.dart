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

import '../incidents/taxonomy.dart';
import '../models/ticket.dart';

class RewardRules {
  const RewardRules({
    this.reportPoints = 2,
    this.attendedPoints = 0,
    this.resolvedBonus = 5,
    this.deniedPoints = 0,
    this.pointsLabel = 'PUNCTE',
  });

  /// Points for filing the initial report.
  final int reportPoints;

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
    required this.reportedCount,
    required this.resolvedCount,
    this.blockedSelfResolutions = 0,
  });

  final List<RewardEntry> entries;
  final int totalPoints;
  final int attendedCount;
  final int reportedCount;
  final int resolvedCount;
  final int blockedSelfResolutions;

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
    final relevant = tickets
        .where(
          (ticket) =>
              ticket.reporterId == crewId ||
              ticket.joinedCrewIds.contains(crewId),
        )
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final entries = <RewardEntry>[];
    var total = 0;
    var attended = 0;
    var reported = 0;
    var resolved = 0;
    var blocked = 0;

    for (final ticket in relevant) {
      final isReporter = ticket.reporterId == crewId;
      final isAttending = ticket.joinedCrewIds.contains(crewId);
      final isResolved = ticket.status == TicketStatus.resolved;
      final resolvedAlone = isResolved &&
          ticket.resolveVoterIds.length == 1 &&
          ticket.resolveVoterIds.contains(crewId);
      final dangerous = ticket.urgency.level >= Urgency.high.level;

      // Anti-farming: a reporter cannot report a non-dangerous incident and
      // resolve it alone just to collect points.
      if (isReporter && isAttending && resolvedAlone && !dangerous) {
        blocked++;
        total += 0;
        entries.add(
          RewardEntry(
            ticket: ticket,
            points: 0,
            reason: 'self_resolution_blocked',
          ),
        );
        continue;
      }

      var points = 0;
      final reasons = <String>[];
      if (isReporter) {
        points += rules.reportPoints;
        reported++;
        reasons.add('reported');
      }
      if (isAttending) {
        attended++;
        // Taking a ticket alone is worth 0: points are only for joining AND
        // solving. A joined-but-unresolved ticket stays at 0 until resolution.
        if (isResolved) {
          points += rules.resolvedBonus;
          resolved++;
          reasons.add('joined_solved');
        } else if (ticket.status == TicketStatus.denied) {
          points += rules.deniedPoints;
          reasons.add('denied');
        } else {
          reasons.add('joined_pending');
        }
      } else if (isResolved) {
        // Reporting a ticket that somebody else resolved earns the report
        // points only; it must not earn the resolver bonus.
        reasons.add('reported_only');
      }
      total += points;
      entries.add(
        RewardEntry(
          ticket: ticket,
          points: points,
          reason: reasons.isEmpty ? 'reported' : reasons.join('+'),
        ),
      );
    }

    return RewardLedger(
      entries: entries,
      totalPoints: total,
      attendedCount: attended,
      reportedCount: reported,
      resolvedCount: resolved,
      blockedSelfResolutions: blocked,
    );
  }
}
