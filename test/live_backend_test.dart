// Live end-to-end test: the real Dart ApiClient against the real FastAPI
// backend over pinned TLS. Opt-in so `flutter test` stays offline by default.
//
// Run (backend must be up via backend\run.ps1):
//   $env:WINGMAN_LIVE='1'
//   flutter test test/live_backend_test.dart
//
// Optional overrides:
//   $env:WINGMAN_API='https://10.10.28.37:8443'
//   $env:WINGMAN_TOKEN='demo-token'
//
// What this proves that the Python smoke test cannot:
//   • SecurityContext CA pinning works in dart:io
//   • WebSocket.connect(customClient: ...) + the real WSS envelope parse
//   • Ticket wire JSON is consumed by the exact app model
//   • The full menu-report → join → vote → resolved flow via the app client

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/api/api_client.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/analyze_result.dart';
import 'package:wingman/core/models/ticket.dart';

final bool _live = Platform.environment['WINGMAN_LIVE'] == '1';
const String _skipReason =
    'offline test set: run with WINGMAN_LIVE=1 while backend\\run.ps1 is active';

Future<ServerEvent> _waitFor(
  List<ServerEvent> events,
  bool Function(ServerEvent event) predicate,
  Duration timeout,
) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    for (final event in List<ServerEvent>.of(events)) {
      if (predicate(event)) return event;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('event not received within ${timeout.inSeconds}s');
}

void main() {
  late ApiClient api;
  late ApiClient badTokenApi;

  setUpAll(() {
    if (!_live) return;
    final caFile = File('backend/certs/ca.crt');
    expect(caFile.existsSync(), isTrue,
        reason: 'run .\\scripts\\gen_certs.ps1 -Force first');
    final caPem = caFile.readAsStringSync();
    final base =
        Platform.environment['WINGMAN_API'] ?? 'https://127.0.0.1:8443';
    final token = Platform.environment['WINGMAN_TOKEN'] ?? 'demo-token';
    api = ApiClient(baseUrl: base, token: token, caPem: caPem);
    badTokenApi = ApiClient(baseUrl: base, token: 'definitely-wrong', caPem: caPem);
  });

  tearDownAll(() async {
    if (!_live) return;
    await api.close();
    await badTokenApi.close();
  });

  test('health over pinned TLS', () async {
    final health = await api.health();
    expect(health['status'], 'ok');
    expect(health['service'], 'wingman-api');
    expect(health['taxonomy_version'], IncidentTaxonomy.schemaVersion);
    expect(health['incident_types'], IncidentTaxonomy.all.length);
  }, skip: _live ? false : _skipReason);

  test('wrong token is rejected with 401', () async {
    await expectLater(
      badTokenApi.health(),
      throwsA(isA<ApiException>()
          .having((error) => error.statusCode, 'statusCode', 401)),
    );
  }, skip: _live ? false : _skipReason);

  test('menu report → list → join → vote → resolved', () async {
    final ticket = await api.report(
      const ReportDraft(
        source: ReportSource.menu,
        transcript: 'Defecțiune bandă transportoare bagaje',
        reporterId: 'dart-live-reporter',
        reporterName: 'Dart Live',
        hintCode: 'MT-BELT',
        useAi: false,
      ),
    );
    expect(ticket.incidentCode, 'MT-BELT');
    expect(ticket.status, TicketStatus.dispatched);
    expect(ticket.aiSource, AiSource.manual);
    expect(ticket.confidence, 1.0);
    expect(ticket.primaryDepartments, contains(Department.baggage));
    expect(ticket.createdAt.isUtc, isTrue);

    final listed = await api.listTickets();
    expect(listed.map((item) => item.id), contains(ticket.id));

    var updated = await api.join(ticket.id, crewId: 'dart-crew-1');
    expect(updated.status, TicketStatus.inProgress);
    expect(updated.isJoinedBy('dart-crew-1'), isTrue);

    updated = await api.vote(ticket.id, crewId: 'dart-crew-1');
    expect(updated.resolveVotes, 1);
    expect(updated.status, TicketStatus.inProgress);

    await api.join(ticket.id, crewId: 'dart-crew-2');
    updated = await api.vote(ticket.id, crewId: 'dart-crew-2');
    expect(updated.status, TicketStatus.resolved);
    expect(updated.resolvedAt, isNotNull);
    expect(updated.hasVotedBy('dart-crew-2'), isTrue);
  }, skip: _live ? false : _skipReason);

  test('dispatcher deny + reclassify', () async {
    final toDeny = await api.report(
      const ReportDraft(
        source: ReportSource.menu,
        transcript: 'Acces neautorizat în zonă restricționată',
        reporterId: 'dart-live-reporter',
        reporterName: 'Dart Live',
        hintCode: 'SC-ACCESS',
        useAi: false,
      ),
    );
    final denied = await api.deny(
      toDeny.id,
      reason: 'test fals pozitiv',
      dispatcherId: 'dart-dispatcher',
    );
    expect(denied.status, TicketStatus.denied);
    expect(denied.decidedBy, 'dart-dispatcher');

    final toReclassify = await api.report(
      const ReportDraft(
        source: ReportSource.menu,
        transcript: 'Aglomerare la controlul de securitate',
        reporterId: 'dart-live-reporter',
        reporterName: 'Dart Live',
        hintCode: 'OP-QUEUE',
        useAi: false,
      ),
    );
    final reclassified = await api.reclassify(
      toReclassify.id,
      incidentCode: 'SF-FIRE',
      urgency: Urgency.critical,
      reason: 'test reclassificare',
      dispatcherId: 'dart-dispatcher',
    );
    expect(reclassified.incidentCode, 'SF-FIRE');
    expect(reclassified.labelRo, 'Foc sau fum în terminal');
    expect(reclassified.urgency, Urgency.critical);
    expect(reclassified.aiSource, AiSource.manual);
    expect(reclassified.primaryDepartments, contains(Department.fireRescue));
  }, skip: _live ? false : _skipReason);

  test('WSS delivers ticket.created and ticket.updated', () async {
    final events = <ServerEvent>[];
    final subscription = api.connectEvents().listen(events.add);

    await _waitFor(
      events,
      (event) => event.isConnectionEvent && event.isConnected,
      const Duration(seconds: 15),
    );

    final ticket = await api.report(
      const ReportDraft(
        source: ReportSource.menu,
        transcript: 'Obiect interzis identificat la control',
        reporterId: 'dart-live-reporter',
        reporterName: 'Dart Live',
        hintCode: 'SC-ITEM',
        useAi: false,
      ),
    );

    final created = await _waitFor(
      events,
      (event) =>
          event.type == ServerEvent.typeTicketCreated &&
          event.ticket?.id == ticket.id,
      const Duration(seconds: 15),
    );
    expect(created.ticket!.incidentCode, 'SC-ITEM');
    expect(created.ticket!.version, greaterThanOrEqualTo(1));

    await api.confirm(ticket.id, dispatcherId: 'dart-dispatcher');
    final updatedEvent = await _waitFor(
      events,
      (event) =>
          event.type == ServerEvent.typeTicketUpdated &&
          event.ticket?.id == ticket.id,
      const Duration(seconds: 15),
    );
    expect(updatedEvent.ticket!.status.isActive, isTrue);

    await subscription.cancel();
  }, skip: _live ? false : _skipReason);

  test('conversational /analyze: question -> slots -> dispatcher cap', () async {
    var result = await api.analyze(
      const AnalyzeRequest(
        transcript: 'Este un miros înțepător, cred că e ceva periculos.',
      ),
    );
    expect(result.question, isNotNull);
    expect(result.ready, isFalse);
    expect(result.fields.incidentCode, isNotNull);
    expect(result.missing, contains('location'));
    expect(result.maxClarifications, 3);

    result = await api.analyze(
      AnalyzeRequest(
        transcript:
            'Este un miros înțepător lângă poarta 12, terminal 1. Nimeni nu este rănit.',
        clarificationsAsked: 1,
        knownIncidentCode: result.fields.incidentCode,
      ),
    );
    expect(result.fields.location, isNotEmpty);
    expect(result.fields.peopleAtRisk, isFalse);
    expect(result.missing, isEmpty);

    final afterMax = await api.analyze(
      const AnalyzeRequest(
        transcript: 'Ceva nu este în regulă.',
        clarificationsAsked: 3,
      ),
    );
    expect(afterMax.question, isNull);
    expect(afterMax.fields.confidence, lessThanOrEqualTo(0.40));
  }, skip: _live ? false : _skipReason);

  test('voice path: real speech WAV -> transcribe -> classification', () async {
    // This is the client-side voice pipeline used by the reporter screen:
    // recorded bytes -> ApiClient.transcribe (pinned TLS) -> local Whisper ->
    // text -> /api/analyze -> closed-taxonomy classification. The fixture is a
    // real spoken sentence synthesized on the laptop (see demo-script.md).
    final wav = File('test/fixtures/spoken_report.wav');
    expect(wav.existsSync(), isTrue,
        reason: 'missing fixture test/fixtures/spoken_report.wav');

    final result = await api.transcribe(
      wav.readAsBytesSync(),
      mimeType: 'audio/wav',
      language: 'en',
      timeout: const Duration(seconds: 120),
    );
    expect(result.text, isNotEmpty);
    expect(result.isEmpty, isFalse);
    expect(result.provider, 'faster-whisper');
    final lower = result.text.toLowerCase();
    expect(lower.contains('smoke') || lower.contains('gate'), isTrue,
        reason: 'unexpected transcription: "${result.text}"');

    final conversation = await api.analyze(
      AnalyzeRequest(transcript: result.text),
    );
    expect(conversation.fields.incidentCode, 'SF-FIRE');
    expect(conversation.fields.confidence, greaterThan(0.5));
  }, skip: _live ? false : _skipReason);

  test('dev reset leaves a clean store', () async {
    await api.devReset();
    final tickets = await api.listTickets();
    expect(tickets, isEmpty);
  }, skip: _live ? false : _skipReason);
}
