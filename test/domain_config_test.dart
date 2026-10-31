import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/domain/domain_config.dart';

void main() {
  group('DomainConfig', () {
    test('parses an application profile from JSON', () {
      final config = DomainConfig.fromJson(<String, dynamic>{
        'schemaVersion': 1,
        'id': 'stadium',
        'branding': <String, dynamic>{
          'appName': 'CrowdGuard',
          'tagline': 'Event response',
          'seedColor': '#7C3AED',
          'icon': 'stadium',
        },
        'features': <String, dynamic>{
          'rewards': true,
          'gpsMap': false,
          'photo': false,
          'accessibility': true,
          'history': false,
          'demoReset': true,
        },
        'quorum': <String, dynamic>{
          'strategy': 'fixed',
          'minimum': 1,
          'fixed': 1,
        },
        'rewards': <String, dynamic>{
          'strategy': 'rule_based',
          'attendedPoints': 1,
          'resolvedBonus': 5,
          'deniedPoints': 0,
          'pointsLabel': 'CREDITE',
        },
        'notifications': <String, dynamic>{
          'roles': <String>['crew'],
          'scope': 'primary_departments',
        },
        'demo': <String, dynamic>{'seedTickets': 3, 'resetEnabled': false},
      });

      expect(config.id, 'stadium');
      expect(config.branding.appName, 'CrowdGuard');
      expect(config.branding.seedColorValue, 0xFF7C3AED);
      expect(config.map.provider, 'openstreetmap');
      expect(config.map.initialLat, closeTo(44.3189, 0.0001));
      expect(config.features.gpsMap, isFalse);
      expect(config.features.rewards, isTrue);
      expect(config.quorum.strategy, 'fixed');
      expect(config.rewards.pointsLabel, 'CREDITE');
      expect(config.notifications.roles, <String>{'crew'});
      expect(config.demo.resetEnabled, isFalse);
    });

    test('fallback and JSON round-trip keep branding/features/rewards', () {
      final json = DomainConfig.fallback.toJson();
      final decoded = jsonDecode(jsonEncode(json)) as Map<String, dynamic>;
      final config = DomainConfig.fromJson(decoded);

      expect(config.branding.appName, 'Wingman');
      expect(config.rewards.pointsLabel, 'PUNCTE');
      expect(config.quorum.strategy, 'one_per_primary_department');
      expect(config.features.photo, isTrue);
    });

    test('missing nested objects fall back safely', () {
      final config = DomainConfig.fromJson(<String, dynamic>{'id': 'empty'});
      expect(config.branding.appName, 'Wingman');
      expect(config.rewards.attendedPoints, 2);
      expect(config.quorum.minimum, 1);
    });
  });
}
