import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/widgets/ticket_media_panel.dart';

const _tinyPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';

Ticket _ticket({bool withPhoto = true, bool withCoords = true}) {
  final now = DateTime.utc(2026, 1, 1, 12);
  return Ticket.fromJson(<String, dynamic>{
    'id': 'ticket-media',
    'incident_code': 'SF-FIRE',
    'label_ro': 'Foc sau fum în terminal',
    'category': 'safety_fire',
    'urgency': 'critical',
    'status': 'dispatched',
    'source': 'voice',
    'reporter_id': 'reporter-1',
    'reporter_name': 'Reporter',
    'transcript': 'fum lângă poarta 12',
    'photo_base64': withPhoto ? _tinyPng : null,
    'location': <String, dynamic>{
      'terminal': 'T1',
      'zone': 'Poarta 12',
      'lat': withCoords ? 44.3189 : null,
      'lng': withCoords ? 23.8864 : null,
      'note': null,
    },
    'confidence': 0.9,
    'ai_source': 'fallback',
    'ai_rationale': null,
    'primary_departments': <String>['fire_rescue'],
    'standby_departments': <String>[],
    'joined_crew_ids': <String>[],
    'resolve_votes': 0,
    'resolve_voter_ids': <String>[],
    'quorum': 1,
    'override_deadline': null,
    'dispatched_at': now.toIso8601String(),
    'resolved_at': null,
    'resolution_note': null,
    'decided_by': null,
    'created_at': now.toIso8601String(),
    'updated_at': now.toIso8601String(),
    'version': 1,
  });
}

void main() {
  testWidgets('photo/map toggle is available for a ticket with media',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketMediaPanel(ticket: _ticket(), height: 120),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Hartă'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.tap(find.text('Hartă'));
    await tester.pump();
    expect(find.byType(FlutterMap), findsOneWidget);

    await tester.tap(find.text('Foto'));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('map is still available when the ticket has no photo',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TicketMediaPanel(
            ticket: _ticket(withPhoto: false, withCoords: false),
            height: 120,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Foto'), findsOneWidget);
    expect(find.text('Hartă'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);

    await tester.tap(find.text('Foto'));
    await tester.pump();
    expect(find.textContaining('Nicio fotografie'), findsOneWidget);
  });
}
