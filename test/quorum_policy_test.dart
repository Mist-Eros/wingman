import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/domain/domain_config.dart';
import 'package:wingman/core/domain/quorum_policy.dart';

void main() {
  group('QuorumPolicy', () {
    test('one responder per primary department by default', () {
      const policy = OnePerPrimaryDepartmentQuorumPolicy();
      expect(policy.requiredFor(0), 1);
      expect(policy.requiredFor(1), 1);
      expect(policy.requiredFor(3), 3);
    });

    test('respects the minimum from the domain profile', () {
      const policy = OnePerPrimaryDepartmentQuorumPolicy(minimum: 2);
      expect(policy.requiredFor(0), 2);
      expect(policy.requiredFor(1), 2);
      expect(policy.requiredFor(4), 4);
    });

    test('fixed strategy ignores department count', () {
      const policy = FixedQuorumPolicy(1);
      expect(policy.requiredFor(0), 1);
      expect(policy.requiredFor(5), 1);
    });

    test('maps both configured strategies', () {
      final onePer = quorumPolicyFromConfig(
        const QuorumConfig(
          strategy: 'one_per_primary_department',
          minimum: 1,
          fixed: 2,
        ),
      );
      final fixed = quorumPolicyFromConfig(
        const QuorumConfig(strategy: 'fixed', minimum: 1, fixed: 2),
      );

      expect(onePer.requiredFor(2), 2);
      expect(fixed.requiredFor(2), 2);
      expect(fixed.requiredFor(4), 2);
    });
  });
}
