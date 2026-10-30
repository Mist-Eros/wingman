// Contract tests: the frozen core API everything else depends on.
// Run with:  flutter test
//
// These are deliberately about CONTRACTS, not UI: taxonomy integrity, enum
// parsing, and the exact JSON wire shape produced/consumed by the backend.

import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/session.dart';
import 'package:wingman/core/models/ticket.dart';

Map<String, dynamic> sampleTicketJson() => <String, dynamic>{
      'id': '4b1f0c2e-1111-2222-3333-444455556666',
      'incident_code': 'SF-FIRE',
      'label_ro': 'Foc sau fum în terminal',
      'category': 'safety_fire',
      'urgency': 'critical',
      'status': 'dispatched',
      'source': 'voice',
      'reporter_id': 'reporter-1',
      'reporter_name': 'Andrei P.',
      'transcript': 'Este fum lângă poarta 12.',
      'location': <String, dynamic>{
        'terminal': 'T1',
        'zone': 'Poarta 12',
        'lat': null,
        'lng': null,
        'note': 'zona de așteptare',
      },
      'confidence': 0.93,
      'ai_source': 'ollama',
      'ai_rationale': 'fum în zona de îmbarcare',
      'primary_departments': <String>['fire_rescue', 'security'],
      'standby_departments': <String>['operations', 'maintenance'],
      'joined_crew_ids': <String>[],
      'resolve_votes': 0,
      'resolve_voter_ids': <String>[],
      'quorum': 2,
      'override_deadline': null,
      'dispatched_at': '2026-10-30T09:00:00.000Z',
      'resolved_at': null,
      'resolution_note': null,
      'decided_by': null,
      'created_at': '2026-10-30T09:00:00.000Z',
      'updated_at': '2026-10-30T09:00:00.000Z',
      'version': 1,
    };

void main() {
  group('IncidentTaxonomy', () {
    test('is valid: 14 types, 4 categories, unique uppercase codes', () {
      IncidentTaxonomy.validate();
      expect(IncidentTaxonomy.all, hasLength(14));
      expect(IncidentTaxonomy.codes.toSet(), hasLength(14));
      expect(IncidentTaxonomy.codes.toSet(), hasLength(IncidentTaxonomy.all.length));

      for (final category in IncidentCategory.values) {
        expect(
          IncidentTaxonomy.byCategory(category),
          isNotEmpty,
          reason: 'category ${category.wire} must have incident types',
        );
      }

      for (final type in IncidentTaxonomy.all) {
        expect(type.code, type.code.toUpperCase(), reason: '${type.code} must be uppercase');
        expect(type.primaryDepartments, isNotEmpty, reason: '${type.code} needs a primary department');
        expect(type.labelRo.trim(), isNotEmpty);
      }
    });

    test('contains the catch-all and parses lookups case-insensitively', () {
      expect(IncidentTaxonomy.isValidCode('OP-OTHER'), isTrue);
      expect(IncidentTaxonomy.byCode('sf-fire')?.code, 'SF-FIRE');
      expect(IncidentTaxonomy.isValidCode('XX-NOT-REAL'), isFalse);
      expect(() => IncidentTaxonomy.requireCode('XX-NOT-REAL'), throwsFormatException);
    });

    test('exports a backend catalog of the same shape', () {
      final catalog = IncidentTaxonomy.toJson();
      expect(catalog['version'], IncidentTaxonomy.schemaVersion);
      expect(catalog['types'], hasLength(14));
      final first = (catalog['types'] as List<dynamic>).first as Map<String, dynamic>;
      expect(first.keys.toSet(), <String>{
        'code',
        'label_ro',
        'category',
        'urgency',
        'primary_departments',
        'standby_departments',
      });
    });
  });

  group('enum wire parsing', () {
    test('accepts backend values', () {
      expect(IncidentCategory.fromWire('safety_fire'), IncidentCategory.safetyFire);
      expect(Urgency.fromWire('critical'), Urgency.critical);
      expect(Department.fromWire('fire_rescue'), Department.fireRescue);
      expect(TicketStatus.fromWire('pending_override'), TicketStatus.pendingOverride);
      expect(ReportSource.fromWire('voice'), ReportSource.voice);
      expect(AiSource.fromWire('manual'), AiSource.manual);
    });

    test('rejects unknown values loudly', () {
      expect(() => IncidentCategory.fromWire('nope'), throwsFormatException);
      expect(() => Urgency.fromWire('nope'), throwsFormatException);
      expect(() => Department.fromWire('nope'), throwsFormatException);
      expect(() => TicketStatus.fromWire('nope'), throwsFormatException);
      expect(() => AiSource.fromWire('nope'), throwsFormatException);
    });

    test('urgency ordering matches the contract (low..critical)', () {
      expect(Urgency.low.level, lessThan(Urgency.medium.level));
      expect(Urgency.medium.level, lessThan(Urgency.high.level));
      expect(Urgency.high.level, lessThan(Urgency.critical.level));
      expect(Urgency.max(Urgency.low, Urgency.critical), Urgency.critical);
      expect(Urgency.max(Urgency.critical, Urgency.low), Urgency.critical);
    });
  });

  group('Ticket wire contract', () {
    test('parses a backend payload', () {
      final ticket = Ticket.fromJson(sampleTicketJson());
      expect(ticket.incidentCode, 'SF-FIRE');
      expect(ticket.category, IncidentCategory.safetyFire);
      expect(ticket.status, TicketStatus.dispatched);
      expect(ticket.status.isActive, isTrue);
      expect(ticket.primaryDepartments, contains(Department.fireRescue));
      expect(ticket.location.display, 'T1 · Poarta 12');
      expect(ticket.confidenceLabel, '93%');
      expect(ticket.createdAt.isUtc, isTrue);
      expect(ticket.hasOverrideDeadline, isFalse);
    });

    test('round-trips every wire key', () {
      final json = sampleTicketJson();
      final ticket = Ticket.fromJson(json);
      expect(ticket.toJson().keys.toSet(), json.keys.toSet());
    });

    test('pending override exposes a 5 second countdown', () {
      final json = sampleTicketJson()
        ..['status'] = 'pending_override'
        ..['override_deadline'] = DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 5))
            .toIso8601String();
      final ticket = Ticket.fromJson(json);
      expect(ticket.isPendingOverride, isTrue);
      expect(ticket.remainingOverrideSeconds(), inInclusiveRange(1, 5));
    });

    test('derive UI helpers', () {
      final ticket = Ticket.fromJson(sampleTicketJson());
      expect(ticket.departmentsLabel, 'Pompieri / Salvare · Securitate');
      expect(ticket.isJoinedBy('crew-1'), isFalse);
      expect(ticket.hasVotedBy('crew-1'), isFalse);
      expect(ticket.ageSeconds(), greaterThanOrEqualTo(0));
    });

    test('copyWith can clear nullable fields', () {
      final ticket = Ticket.fromJson(sampleTicketJson());
      final cleared = ticket.copyWith(status: TicketStatus.resolved, decidedBy: null);
      expect(cleared.status, TicketStatus.resolved);
      expect(cleared.decidedBy, isNull);
      expect(cleared.id, ticket.id);
    });
  });

  group('ReportDraft wire contract', () {
    test('serializes the menu flow', () {
      const draft = ReportDraft(
        source: ReportSource.menu,
        transcript: 'Defecțiune bandă transportoare bagaje',
        reporterId: 'reporter-1',
        reporterName: 'Mihai D.',
        hintCode: 'MT-BELT',
        useAi: false,
      );
      final map = draft.toJson();
      expect(map['source'], 'menu');
      expect(map['hint_code'], 'MT-BELT');
      expect(map['use_ai'], isFalse);
      expect(map.keys.toSet(), <String>{
        'source',
        'transcript',
        'reporter_id',
        'reporter_name',
        'location',
        'hint_code',
        'use_ai',
      });
    });
  });

  group('Session', () {
    test('demo sessions are unique and encode/decode', () {
      final a = Session.demo(UserRole.dispatcher, displayName: 'Dana');
      final b = Session.demo(UserRole.crew);
      expect(a.userId, isNot(b.userId));
      expect(a.displayName, 'Dana');
      expect(b.displayName, 'Echipaj demo');
      final roundTrip = Session.decode(a.encode());
      expect(roundTrip.role, UserRole.dispatcher);
      expect(roundTrip.userId, a.userId);
      expect(UserRole.fromWire('crew'), UserRole.crew);
    });
  });
}
