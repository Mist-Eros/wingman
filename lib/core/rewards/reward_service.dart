import '../../core/domain/domain_config.dart';
import '../../core/models/ticket.dart';
import 'reward_policy.dart';

/// Thin application service around a [RewardPolicy]. Inject a different policy
/// (badges, shift multipliers, leaderboards) without changing the UI.
class RewardService {
  const RewardService({
    this.policy = const RuleBasedRewardPolicy(),
    this.pointsLabel = 'PUNCTE',
  });

  final RewardPolicy policy;

  /// UI-facing label; comes from the domain profile via [fromDomain].
  final String pointsLabel;

  static RewardService fromDomain(DomainConfig domain) {
    return RewardService(
      pointsLabel: domain.rewards.pointsLabel,
      policy: RuleBasedRewardPolicy(
        rules: RewardRules(
          attendedPoints: domain.rewards.attendedPoints,
          resolvedBonus: domain.rewards.resolvedBonus,
          deniedPoints: domain.rewards.deniedPoints,
          pointsLabel: domain.rewards.pointsLabel,
        ),
      ),
    );
  }

  RewardLedger ledgerFor({
    required String crewId,
    required Iterable<Ticket> tickets,
  }) {
    return policy.ledgerFor(crewId: crewId, tickets: tickets);
  }
}
