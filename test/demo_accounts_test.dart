// Contract tests for the hardcoded demo accounts + department-scoped alerts.
// These protect the two things the judges will ask about:
//   1. passwords are stored as salted hashes (never clear text) and validated;
//   2. a scoped account only sees the departments it is responsible for.
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/auth/demo_accounts.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/session.dart';

void main() {
  group('demo accounts', () {
    test('has the four hardcoded accounts with hashed passwords', () {
      expect(demoAccounts.length, greaterThanOrEqualTo(4));
      for (final account in demoAccounts) {
        expect(account.passwordHash.length, 64,
            reason: '${account.username} must store a SHA-256 hex hash');
        expect(account.passwordHash, isNot(account.passwordHint),
            reason: 'clear-text password must never be stored');
      }
    });

    test('Mandy Medic is scoped to the medical department', () {
      final mandy = demoAccountByUsername('medic');
      expect(mandy, isNotNull);
      expect(mandy!.displayName, 'Mandy Medic');
      expect(mandy.tag, 'MEDIC');
      expect(mandy.checkPassword('medic123'), isTrue);
      final session = mandy.toSession();
      expect(session.departments, <Department>{Department.medical});
      expect(session.isCrew, isTrue);
    });

    test('validates the demo password and rejects a wrong one', () {
      final janitor = demoAccountByUsername('janitor')!;
      expect(janitor.checkPassword('janitor123'), isTrue);
      expect(janitor.checkPassword('admin123'), isFalse);
      expect(janitor.checkPassword(''), isFalse);
    });

    test('admin sees everything, scoped accounts do not', () {
      final admin = demoAccountByUsername('admin')!.toSession();
      final janitor = demoAccountByUsername('janitor')!.toSession();
      final engineer = demoAccountByUsername('engineer')!.toSession();

      expect(admin.isAdmin, isTrue);
      expect(
          admin.seesDepartments(<Department>[Department.maintenance]), isTrue);
      expect(admin.seesDepartments(<Department>[Department.terminal]), isTrue);

      // Janitor: terminal only.
      expect(
          janitor.seesDepartments(<Department>[Department.terminal]), isTrue);
      expect(janitor.seesDepartments(<Department>[Department.maintenance]),
          isFalse);
      expect(janitor.seesDepartments(<Department>[Department.it]), isFalse);

      // Engineer: technical departments only.
      expect(engineer.seesDepartments(<Department>[Department.maintenance]),
          isTrue);
      expect(engineer.seesDepartments(<Department>[Department.it]), isTrue);
      expect(
          engineer.seesDepartments(<Department>[Department.terminal]), isFalse);
    });

    test('session round-trips the account scope', () {
      final engineer = demoAccountByUsername('engineer')!.toSession();
      final decoded = Session.decode(engineer.encode());
      expect(decoded.username, 'engineer');
      expect(decoded.isAdmin, isFalse);
      expect(decoded.departments, engineer.departments);
      expect(decoded.scopeLabel, contains('Mentenanță'));
    });

    test('restoreSession upgrades an old saved session', () {
      final legacy = Session.demo(UserRole.crew, displayName: 'Echipaj demo');
      final restored = restoreSession(legacy);
      // Unknown username → untouched legacy session.
      expect(restored.userId, legacy.userId);

      final saved = Session(
        role: UserRole.crew,
        userId: 'crew-1',
        displayName: 'John',
        username: 'janitor',
      );
      final upgraded = restoreSession(saved);
      expect(upgraded.userId, 'acct-janitor');
      expect(upgraded.departments, contains(Department.terminal));
      expect(upgraded.displayName, 'John');
    });
  });
}
