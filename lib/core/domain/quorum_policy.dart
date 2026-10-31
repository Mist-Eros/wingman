// Quorum is a policy, not a number wired into the store or UI.
//
// The backend has an equivalent implementation (backend/app/domain.py) fed by
// the same config/domains/*.json file. Add a new strategy by implementing
// [QuorumPolicy] and selecting it in the JSON.

import 'dart:math' as math;

import '../domain/domain_config.dart';

abstract interface class QuorumPolicy {
  int requiredFor(int primaryDepartmentCount);
}

/// One responder is required for every primary department involved.
class OnePerPrimaryDepartmentQuorumPolicy implements QuorumPolicy {
  const OnePerPrimaryDepartmentQuorumPolicy({this.minimum = 1});

  final int minimum;

  @override
  int requiredFor(int primaryDepartmentCount) =>
      math.max(minimum, primaryDepartmentCount);
}

/// A fixed number regardless of departments (useful for simple venues).
class FixedQuorumPolicy implements QuorumPolicy {
  const FixedQuorumPolicy(this.required);

  final int required;

  @override
  int requiredFor(int primaryDepartmentCount) => math.max(1, required);
}

QuorumPolicy quorumPolicyFromConfig(QuorumConfig config) {
  return switch (config.strategy) {
    'fixed' => FixedQuorumPolicy(config.fixed),
    _ => OnePerPrimaryDepartmentQuorumPolicy(minimum: config.minimum),
  };
}
