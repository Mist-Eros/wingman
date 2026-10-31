// Reporter flow tests: fake microphone / TTS / GPS / server, no device needed.
// Run with:  flutter test test/reporter_controller_test.dart
//
// The fake server below is deliberately DUMB (it never classifies and never
// asks): the questions must come from the reporter's own brain.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/api/api_client.dart';
import 'package:wingman/core/incidents/taxonomy.dart';
import 'package:wingman/core/models/analyze_result.dart';
import 'package:wingman/core/models/ticket.dart';
import 'package:wingman/core/models/transcription_result.dart';
import 'package:wingman/features/reporter/reporter_controller.dart';
import 'package:wingman/features/reporter/reporter_language.dart';
import 'package:wingman/features/reporter/reporter_screen.dart';
import 'package:wingman/features/reporter/services/location_service.dart';
import 'package:wingman/features/reporter/services/speech_service.dart';
import 'package:wingman/features/reporter/services/tts_service.dart';

import 'core_contract_test.dart' show sampleTicketJson;

class FakeSpeech implements SpeechService {
  bool micOk = true;
  int listenCount = 0;
  int cancelCount = 0;
  int stopCount = 0;
  bool? lastAutoStop;
  ReporterLanguage? lastLanguage;

  void Function(double level)? _onLevel;
  void Function()? _onProcessing;
  void Function(TranscriptionResult result)? _onResult;
  void Function(String message)? _onError;

  @override
  Future<bool> initialize() async => micOk;

  @override
  Future<void> listen({
    required ReporterLanguage language,
    required void Function(double level) onLevel,
    required void Function() onProcessing,
    required void Function(TranscriptionResult result) onResult,
    required void Function(String message) onError,
    bool autoStop = true,
  }) async {
    listenCount++;
    lastAutoStop = autoStop;
    lastLanguage = language;
    _onLevel = onLevel;
    _onProcessing = onProcessing;
    _onResult = onResult;
    _onError = onError;
  }

  /// The reporter says something and releases: Whisper answers.
  void say(
    String text, {
    List<TranscriptionWord> words = const <TranscriptionWord>[],
  }) {
    _onProcessing?.call();
    _onResult?.call(TranscriptionResult(text: text, words: words));
  }

  void level(double value) => _onLevel?.call(value);

  void fail(String message) => _onError?.call(message);

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }
}

class FakeTts implements TtsService {
  final List<({String text, ReporterLanguage language})> spoken =
      <({String text, ReporterLanguage language})>[];

  @override
  Future<void> speak(String text, ReporterLanguage language) async {
    spoken.add((text: text, language: language));
  }

  @override
  Future<void> stop() async {}
}

class FakeLocation implements LocationService {
  @override
  Future<LocationFix?> current() async =>
      const LocationFix(lat: 44.57, lng: 26.09, accuracyMeters: 18);
}

/// A server that understands nothing and asks nothing.
AnalyzeResult _dumbServer(AnalyzeRequest request) =>
    const AnalyzeResult(fields: AnalyzeFields(), ready: true);

class Harness {
  Harness({
    AnalyzeResult Function(AnalyzeRequest request)? respond,
    ReporterLanguage language = ReporterLanguage.ro,
    int maxQuestions = 3,
  }) : _respond = respond ?? _dumbServer {
    controller = ReporterController(
      speech: speech,
      tts: tts,
      analyze: _analyze,
      report: _report,
      reporterId: 'reporter-1',
      reporterName: 'Andrei',
      location: FakeLocation(),
      language: language,
      minHold: const Duration(milliseconds: 20),
      maxQuestions: maxQuestions,
    );
  }

  final AnalyzeResult Function(AnalyzeRequest request) _respond;
  final FakeSpeech speech = FakeSpeech();
  final FakeTts tts = FakeTts();
  final List<AnalyzeRequest> analyzeRequests = <AnalyzeRequest>[];
  final List<ReportDraft> reports = <ReportDraft>[];
  late final ReporterController controller;

  /// When set, `_analyze` waits for it (to test stale replies).
  Completer<AnalyzeResult>? gate;
  Object? analyzeError;

  Future<AnalyzeResult> _analyze(AnalyzeRequest request) async {
    analyzeRequests.add(request);
    final error = analyzeError;
    if (error != null) throw error;
    final pending = gate;
    if (pending != null) return pending.future;
    return _respond(request);
  }

  Future<Ticket> _report(ReportDraft draft) async {
    reports.add(draft);
    return Ticket.fromJson(sampleTicketJson());
  }

  Future<void> settle() => pumpEventQueue();

  /// Push-to-talk: hold the mic, say [text], release; then wait for the
  /// controller to settle (Whisper + analyze).
  Future<void> speak(
    String text, {
    List<TranscriptionWord> words = const <TranscriptionWord>[],
  }) async {
    await controller.micDown();
    await settle();
    await Future<void>.delayed(const Duration(milliseconds: 40));
    await controller.micUp();
    speech.say(text, words: words);
    await settle();
  }

  String? get question => controller.question;
}

void main() {
  group('conversation (the reporter speaks first)', () {
    test('asks only what is missing, each thing once, in a useful order',
        () async {
      final h = Harness();
      final c = h.controller;

      await h.speak('am o pată de ulei');
      expect(c.phase, ReporterPhase.asking);
      expect(h.question, contains('Unde'));
      expect(h.tts.spoken.single.text, contains('Unde'));
      // push-to-talk: recording is held by the finger, never hands-free
      expect(h.speech.listenCount, 1);
      expect(h.speech.lastAutoStop, isFalse);

      await h.speak('poarta 12');
      expect(c.phase, ReporterPhase.asking);
      expect(h.question, contains('Cât de mare'));

      await h.speak('destul de mare');
      expect(c.phase, ReporterPhase.confirming);
      expect(c.question, isNull);

      // the server saw the growing transcript and the real question count
      expect(
          h.analyzeRequests.map((r) => r.clarificationsAsked), <int>[0, 1, 2]);
      expect(h.analyzeRequests.last.transcript,
          'am o pată de ulei poarta 12 destul de mare');

      await c.submit();
      final draft = h.reports.single;
      expect(draft.source, ReportSource.voice);
      // what was said, exactly as said
      expect(draft.transcript, 'am o pată de ulei poarta 12 destul de mare');
      expect(draft.location.zone, 'Poarta 12');
      expect(draft.location.note, 'Dimensiune: destul de mare');
      expect(draft.location.lat, 44.57);
      expect(draft.location.lng, 26.09);
      expect(draft.useAi, isTrue);
      expect(c.phase, ReporterPhase.sent);
      expect(c.sentTicket, isNotNull);
    });

    test('everything said in the first sentence: no questions at all',
        () async {
      final h = Harness();
      await h.speak('o pată mare de ulei la poarta 12');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.tts.spoken, isEmpty);
      expect(h.controller.details, <String, String>{'size': 'mare'});
    });

    test('BUG FIX: the type is asked once and the answer is accepted',
        () async {
      final h = Harness();
      await h.speak('ceva nu e în regulă la poarta 3');
      expect(h.question, contains('Ce tip de problemă'));
      expect(h.question, isNot(contains('exemplu')));

      await h.speak('scurgere');
      // the type is now known: the next question is about the problem
      expect(h.question, isNot(contains('Ce tip')));
      expect(h.question, contains('Cât de mare'));

      await h.speak('mică');
      expect(h.controller.phase, ReporterPhase.confirming);
      final asked = h.tts.spoken.map((s) => s.text).toList();
      expect(asked.where((q) => q.contains('Ce tip')), hasLength(1));
      expect(h.controller.result!.fields.incidentCode, 'SF-SPILL');
    });

    test('an answer nobody can classify is kept, never asked again', () async {
      final h = Harness();
      await h.speak('ceva nu e în regulă la poarta 3');
      await h.speak('nu prea știu, e ciudat');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.controller.transcript,
          'ceva nu e în regulă la poarta 3 nu prea știu, e ciudat');
      expect(h.controller.result!.missing, contains('incident_code'));
      expect(h.tts.spoken, hasLength(1));

      await h.controller.submit();
      // the dispatcher gets the reporter's own words
      expect(h.reports.single.transcript, contains('nu prea știu, e ciudat'));
    });

    test('a category word is enough ("securitate")', () async {
      final h = Harness();
      await h.speak('ceva nu e în regulă la poarta 3');
      await h.speak('securitate');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.controller.result!.fields.labelRo, 'Securitate');
    });

    test('the question cap is respected', () async {
      final h = Harness(maxQuestions: 1);
      await h.speak('o pată de ulei');
      expect(h.question, contains('Unde'));
      await h.speak('nu știu');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.tts.spoken, hasLength(1));
    });

    test('"Trimite oricum" skips the questions', () async {
      final h = Harness();
      await h.speak('fum');
      expect(h.controller.phase, ReporterPhase.asking);
      h.controller.skipQuestions();
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.controller.question, isNull);
    });

    test('English: questions are asked and spoken in English', () async {
      final h = Harness(language: ReporterLanguage.en);
      await h.speak('there is an oil spill');
      final spoken = h.tts.spoken.single;
      expect(spoken.text, startsWith('Where is it?'));
      expect(spoken.language, ReporterLanguage.en);
      expect(h.speech.lastLanguage, ReporterLanguage.en);

      await h.speak('gate twelve');
      expect(h.question, startsWith('How big is the spill?'));
      await h.speak('about two meters');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.controller.details['size'], 'about two meters');
    });

    test('fire: goes straight to confirmation, no people question', () async {
      final h = Harness();
      await h.speak('este fum la terminal 2');
      expect(h.question, isNull);
      expect(h.controller.phase, ReporterPhase.confirming);
      await h.controller.submit();
      expect(h.reports.single.transcript, contains('fum'));
    });

    test('typed text goes through the same pipeline', () async {
      final h = Harness();
      h.controller.submitText('  pată mare de ulei la sectorul 3 ');
      await h.settle();
      expect(h.analyzeRequests.single.transcript,
          'pată mare de ulei la sectorul 3');
      expect(h.controller.phase, ReporterPhase.confirming);
    });

    test('a smart server is respected: its type and confidence are shown',
        () async {
      final h = Harness(
        respond: (_) => AnalyzeResult(
          fields: AnalyzeFields(
            incidentCode: 'SF-SPILL',
            labelRo: IncidentTaxonomy.byCode('SF-SPILL')!.labelRo,
            location: 'Poarta 12',
            urgency: Urgency.critical,
            confidence: 0.93,
            aiSource: AiSource.ollama,
          ),
          ready: true,
        ),
      );
      await h.speak('ceva s-a vărsat');
      // The server already has type + place and says "ready": the app must not
      // invent the local "size" question after that.
      expect(h.question, isNull);
      expect(h.controller.phase, ReporterPhase.confirming);
      final fields = h.controller.result!.fields;
      expect(fields.confidence, 0.93);
      expect(fields.aiSource, AiSource.ollama);
      expect(fields.location, 'Poarta 12');
    });
  });

  group('errors', () {
    test('silence is reported, nothing is sent to the server', () async {
      final h = Harness();
      await h.speak('');
      expect(h.controller.error, ReporterError.noSpeech);
      expect(h.controller.phase, ReporterPhase.idle);
      expect(h.analyzeRequests, isEmpty);
    });

    test('no microphone permission', () async {
      final h = Harness();
      h.speech.micOk = false;
      await h.controller.micDown();
      expect(h.controller.error, ReporterError.micUnavailable);
      expect(h.controller.phase, ReporterPhase.idle);
    });

    test('an accidental tap (released too early) sends nothing', () async {
      final h = Harness();
      await h.controller.micDown();
      await h.settle();
      expect(h.controller.phase, ReporterPhase.listening);
      await h.controller.micUp(); // immediately: shorter than minHold
      expect(h.controller.error, ReporterError.holdToTalk);
      expect(h.controller.phase, ReporterPhase.idle);
      expect(h.speech.stopCount, 0);
      expect(h.speech.cancelCount, greaterThan(0));
      expect(h.analyzeRequests, isEmpty);
    });

    test('release ends the recording: stop() is called exactly once', () async {
      final h = Harness();
      await h.controller.micDown();
      await h.settle();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await h.controller.micUp();
      expect(h.speech.stopCount, 1);
    });

    test('Whisper failure keeps the message and returns to idle', () async {
      final h = Harness();
      await h.controller.micDown();
      await h.settle();
      h.speech.fail('Serverul nu are încă /api/transcribe');
      await h.settle();
      expect(h.controller.error, ReporterError.transcribe);
      expect(h.controller.errorDetail, contains('/api/transcribe'));
      expect(h.controller.phase, ReporterPhase.idle);
    });

    test('AI server down: the conversation still works locally', () async {
      final h = Harness();
      h.analyzeError = ApiException('Cannot reach server');
      await h.speak('am o pată de ulei');
      // it still understood the spill and asks the next missing thing
      expect(h.controller.error, ReporterError.aiOffline);
      expect(h.controller.phase, ReporterPhase.asking);
      expect(h.question, contains('Unde'));
      expect(h.controller.result, isNotNull);

      await h.speak('poarta 3, mare');
      expect(h.controller.phase, ReporterPhase.confirming);
      expect(h.controller.result!.fields.incidentCode, 'SF-SPILL');
    });
  });

  group('confirmation', () {
    test('"Reia de la capăt" drops everything and goes back to the mic',
        () async {
      final h = Harness();
      await h.speak('o pată mare de ulei la poarta 12');
      expect(h.controller.phase, ReporterPhase.confirming);

      await h.controller.restart();
      await h.settle();
      expect(h.controller.transcript, isEmpty);
      expect(h.controller.result, isNull);
      expect(h.controller.details, isEmpty);
      expect(h.controller.hintCode, isNull);
      expect(h.controller.clarificationsAsked, 0);
      // back on the mic screen, waiting for a NEW hold (never hands-free)
      expect(h.controller.phase, ReporterPhase.idle);
      expect(h.speech.cancelCount, greaterThan(0));

      await h.speak('fum la poarta 3');
      expect(h.analyzeRequests.last.transcript, 'fum la poarta 3');
      expect(h.analyzeRequests.last.clarificationsAsked, 0);
    });

    test('a late server answer after "start over" is ignored', () async {
      final h = Harness();
      final slowReply = Completer<AnalyzeResult>();
      h.gate = slowReply;
      await h.speak('fum la poarta 3');
      expect(h.controller.phase, ReporterPhase.analyzing);

      await h.controller.restart();
      await h.settle();
      expect(h.controller.phase, ReporterPhase.idle);

      // The reply to the OLD recording finally arrives: it must not touch
      // the new, empty report.
      slowReply.complete(_dumbServer(
        const AnalyzeRequest(transcript: ''),
      ));
      await h.settle();
      expect(h.controller.phase, ReporterPhase.idle);
      expect(h.controller.result, isNull);
      expect(h.controller.transcript, isEmpty);
    });

    test('tapping a word replaces it and re-analyses; empty removes it',
        () async {
      final h = Harness();
      await h.speak('pată mare de ulei la sectorul 3');
      expect(h.controller.words,
          <String>['pată', 'mare', 'de', 'ulei', 'la', 'sectorul', '3']);

      h.controller.editWord(3, 'combustibil');
      await h.settle();
      expect(h.analyzeRequests.last.transcript,
          'pată mare de combustibil la sectorul 3');
      expect(h.analyzeRequests.last.knownIncidentCode, isNull);
      expect(h.controller.phase, ReporterPhase.confirming);

      h.controller.editWord(0, '');
      await h.settle();
      expect(h.analyzeRequests.last.transcript,
          'mare de combustibil la sectorul 3');
    });

    test('words of a spoken ANSWER can be corrected too', () async {
      final h = Harness();
      await h.speak('am o pată de ulei');
      await h.speak('poarta 12');
      await h.speak('mare');
      expect(h.controller.phase, ReporterPhase.confirming);
      // "poarta 12" are words 5 and 6 (0-based: am o pată de ulei | poarta 12 | mare)
      h.controller.editWord(6, '14');
      await h.settle();
      expect(h.controller.transcript, 'am o pată de ulei poarta 14 mare');
      expect(h.controller.result!.fields.location, 'Poarta 14');
      // fixing a word never re-asks anything
      expect(h.controller.phase, ReporterPhase.confirming);
    });

    test('picking a type from the menu is trusted (no AI on send)', () async {
      final h = Harness();
      await h.speak('ceva pe pistă');
      expect(h.question, contains('Ce tip'));
      h.controller.skipQuestions();
      final other = IncidentTaxonomy.all.last;
      h.controller.pickType(other);
      await h.settle();
      expect(h.analyzeRequests.last.hintCode, other.code);
      expect(h.controller.result!.fields.incidentCode, other.code);

      await h.controller.submit();
      expect(h.reports.single.hintCode, other.code);
      expect(h.reports.single.useAi, isFalse);
    });

    test('double tap on Send creates one ticket', () async {
      final h = Harness();
      await h.speak('o pată mare de ulei la poarta 3');
      final first = h.controller.submit();
      final second = h.controller.submit();
      await Future.wait(<Future<void>>[first, second]);
      expect(h.reports, hasLength(1));
    });
  });

  group('menu', () {
    test('menu report carries the optional photo into ReportDraft', () async {
      final h = Harness();
      final type = IncidentTaxonomy.all.first;
      await h.controller.submitMenu(
        type,
        locationText: 'Poarta 12',
        photoBase64: 'cGhvdG8=',
      );
      expect(h.reports.single.photoBase64, 'cGhvdG8=');
    });

    test('menu report: no questions, no AI, hint code + typed place', () async {
      final h = Harness();
      final type = IncidentTaxonomy.all.first;
      await h.controller.submitMenu(type, locationText: ' Poarta 12 ');
      final draft = h.reports.single;
      expect(draft.source, ReportSource.menu);
      expect(draft.hintCode, type.code);
      expect(draft.useAi, isFalse);
      expect(draft.transcript, type.labelRo);
      expect(draft.location.zone, 'Poarta 12');
      expect(h.analyzeRequests, isEmpty);
      expect(h.controller.phase, ReporterPhase.sent);
    });
  });

  group('screen', () {
    testWidgets('idle screen, then tap a word to correct it', (tester) async {
      final h = Harness();
      await tester.pumpWidget(MaterialApp(
        home: ReporterScreen(controller: h.controller),
      ));
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Nu pot vorbi — meniu'), findsOneWidget);

      h.controller.submitText('pată mare de ulei la poarta 3');
      await tester.pumpAndSettle();
      expect(find.text('Verifică raportul'), findsOneWidget);
      expect(find.text('Reia de la capăt'), findsOneWidget);
      // the size the reporter volunteered is on the card
      expect(find.text('Dimensiune: '), findsOneWidget);

      await tester.tap(find.text('ulei'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'petrol');
      await tester.tap(find.text('Salvează'));
      await tester.pumpAndSettle();

      expect(
          h.analyzeRequests.last.transcript, 'pată mare de petrol la poarta 3');
      expect(find.text('petrol'), findsOneWidget);
    });

    test('Whisper word probabilities underline only low-confidence words',
        () async {
      final h = Harness();
      await h.speak(
        'este fum lângă poarta 12',
        words: const <TranscriptionWord>[
          TranscriptionWord(text: 'este', probability: 0.95),
          TranscriptionWord(text: 'fum', probability: 0.92),
          TranscriptionWord(text: 'poarta', probability: 0.35),
          TranscriptionWord(text: '12', probability: 0.80),
        ],
      );
      final c = h.controller;
      expect(c.words, <String>['este', 'fum', 'poarta', '12']);
      expect(c.lowConfidenceCount, 1);
      expect(c.isLowConfidence(0), isFalse);
      expect(c.isLowConfidence(2), isTrue);
      expect(c.isWordEditable(0), isFalse);
      expect(c.isWordEditable(2), isTrue);
      c.editWord(0, 'nu-se-poate');
      expect(c.words.first, 'este',
          reason: 'high-confidence word is read-only');
      c.editWord(2, 'Poarta');
      expect(c.words[2], 'Poarta');
      expect(c.isLowConfidence(2), isFalse,
          reason: 'a corrected word becomes trusted');
    });

    test('uniformly low Whisper confidence does not paint every word yellow',
        () async {
      final h = Harness();
      await h.speak(
        'fum langa poarta',
        words: const <TranscriptionWord>[
          TranscriptionWord(text: 'fum', probability: 0.52),
          TranscriptionWord(text: 'langa', probability: 0.48),
          TranscriptionWord(text: 'poarta', probability: 0.50),
        ],
      );
      final c = h.controller;
      expect(c.transcriptConfidenceLow, isTrue);
      expect(c.lowConfidenceCount, 0,
          reason: 'no word is a clear outlier in a uniformly low sentence');
      expect(c.wordEditability, everyElement(isTrue),
          reason:
              'the whole sentence is uncertain, so every word can be fixed');
    });

    testWidgets('holding the mic records, releasing it ends the take',
        (tester) async {
      final h = Harness();
      await tester.pumpWidget(MaterialApp(
        home: ReporterScreen(controller: h.controller),
      ));
      final gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.mic_rounded)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(h.controller.phase, ReporterPhase.listening);
      expect(
          find.text('Te ascult… eliberează când ai terminat.'), findsOneWidget);

      // DateTime.now is real time even in testWidgets: wait past minHold.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 60)),
      );
      await gesture.up();
      await tester.pump();
      expect(h.speech.stopCount, 1);
    });

    testWidgets('language toggle switches the UI to English', (tester) async {
      final h = Harness();
      await tester.pumpWidget(MaterialApp(
        home: ReporterScreen(controller: h.controller),
      ));
      await tester.tap(find.text('EN'));
      await tester.pumpAndSettle();
      expect(find.text('Say what happened'), findsOneWidget);
      expect(find.text("Can't talk — menu"), findsOneWidget);
    });
  });
}
