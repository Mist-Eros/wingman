// State machine of the reporter flow. UI-free so it can be unit-tested with
// fake speech / TTS / location / API.
//
//   idle ──hold mic──► listening ──release──► transcribing ──► analyzing
//                                                                 │
//        ┌──────────── something missing? ────────────────────────┤
//        ▼                                                        ▼
//     asking ──hold mic to answer──► …                       confirming ──► submitting ──► sent
//
// WHAT to ask is decided by [ConversationBrain] (brain/): only what is
// missing, each thing at most once, adapted to the kind of problem, and every
// answer is kept exactly as said. The server (Ollama via POST /api/analyze) is
// the classifier of record; when it is slow or down the brain still works.

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/api/api_client.dart';
import '../../core/incidents/taxonomy.dart';
import '../../core/models/analyze_result.dart';
import '../../core/models/ticket.dart';
import '../../core/models/transcription_result.dart';
import 'brain/conversation_brain.dart';
import 'reporter_language.dart';
import 'services/location_service.dart';
import 'services/speech_service.dart';
import 'services/tts_service.dart';

enum ReporterPhase {
  idle,
  listening,
  transcribing,
  analyzing,
  asking,
  confirming,
  submitting,
  sent,
}

enum ReporterError {
  micUnavailable,
  noSpeech,

  /// Button released too early (or the permission dialog ate the press).
  holdToTalk,
  transcribe,

  /// The AI server did not answer analysis; the app understood locally.
  aiOffline,
  server,
}

typedef AnalyzeFn = Future<AnalyzeResult> Function(AnalyzeRequest request);
typedef ReportFn = Future<Ticket> Function(ReportDraft draft);
typedef EditTicketFn = Future<Ticket> Function(
  String ticketId, {
  String? transcript,
  String? photoBase64,
});

/// One recognised word; [confidence] is null for typed/menu input or when the
/// STT server cannot provide word-level probabilities.
class _Word {
  _Word(this.text, this.confidence);

  String text;
  double? confidence;
}

/// One thing the reporter said (one press of the mic, or one typed text).
class _Turn {
  _Turn(this.slot, this.words);

  /// The question this answers ('type', 'location', 'size', ...), or null.
  final String? slot;
  final List<_Word> words;
}

class ReporterController extends ChangeNotifier {
  ReporterController({
    required SpeechService speech,
    required TtsService tts,
    required AnalyzeFn analyze,
    required ReportFn report,
    required this.reporterId,
    this.editTicketFn,
    required this.reporterName,
    LocationService? location,
    ReporterLanguage language = ReporterLanguage.ro,
    this.minHold = const Duration(milliseconds: 400),
    this.maxQuestions = 3,
    this.onLowConfidenceMenu,
  })  : _speech = speech,
        _tts = tts,
        _analyzeFn = analyze,
        _reportFn = report,
        _location = location,
        _language = language;

  /// A press shorter than this is treated as an accidental tap.
  final Duration minHold;

  /// Questions per report (the server enforces the same cap of 3).
  final int maxQuestions;

  /// Called when the reporter's second voice attempt is still unusable. The
  /// screen opens the 8×8×8 menu; tests can leave it null.
  final Future<void> Function()? onLowConfidenceMenu;

  final SpeechService _speech;
  final TtsService _tts;
  final AnalyzeFn _analyzeFn;
  final ReportFn _reportFn;
  final EditTicketFn? editTicketFn;
  final LocationService? _location;
  final String reporterId;
  final String reporterName;
  final ConversationBrain _brain = ConversationBrain();

  ReporterLanguage _language;
  ReporterPhase _phase = ReporterPhase.idle;
  final List<_Turn> _turns = <_Turn>[];
  String? _pendingSlot;
  double _level = 0;
  AnalyzeResult? _result;
  Map<String, String> _details = const <String, String>{};
  String? _question;
  bool _keepKnownCode = false;
  String? _serverCode;
  String? _hintCode;
  ReporterError? _error;
  String? _errorDetail;
  Ticket? _sent;
  bool _transcriptCorrected = false;
  bool _lowConfidenceReaskUsed = false;
  bool _manualMenuRequested = false;
  LocationFix? _fix;

  /// Bumped by every reset; async work started before the bump is ignored.
  int _epoch = 0;
  bool _disposed = false;

  // Push-to-talk bookkeeping.
  bool _held = false;
  bool _listenStarted = false;
  DateTime? _holdStart;

  // ── read-only state for the UI ────────────────────────────────────────────

  ReporterLanguage get language => _language;
  ReporterPhase get phase => _phase;

  /// Everything the reporter said, verbatim, in order.
  String get transcript => words.join(' ');

  /// Microphone input level 0..1 while [phase] is listening.
  double get level => _level;

  /// What the app understood (server + local), for the confirmation card.
  AnalyzeResult? get result => _result;

  /// Follow-up details the reporter gave (size, people...), slot → text.
  Map<String, String> get details => _details;

  /// Question currently shown/spoken (null when nothing is asked).
  String? get question => _question;
  int get clarificationsAsked => _brain.askedCount;

  /// Type the reporter forced from the menu while confirming (or null).
  String? get hintCode => _hintCode;
  ReporterError? get error => _error;
  String? get errorDetail => _errorDetail;
  Ticket? get sentTicket => _sent;
  LocationFix? get fix => _fix;

  /// True when the LLM fixed the Whisper sentence before it was shown.
  bool get transcriptCorrected => _transcriptCorrected;

  /// True after the second unusable voice attempt; the 8×8×8 menu is required.
  bool get manualMenuRequested => _manualMenuRequested;

  List<String> get words => <String>[
        for (final turn in _turns)
          for (final word in turn.words) word.text,
      ];

  /// Parallel to [words]; null when Whisper had no word-level metadata.
  List<double?> get wordConfidences => <double?>[
        for (final turn in _turns)
          for (final word in turn.words) word.confidence,
      ];

  /// Words that are genuinely uncertain *relative to the rest of this
  /// sentence*. A fixed 0.70 cut-off painted every word yellow on noisy audio
  /// (a small model often sits at 0.4–0.6 for the whole utterance), so we mark
  /// only the clear outliers:
  ///   - if the best word is >= 0.70: mark words below (best - 0.18);
  ///   - if the whole sentence is low: no yellow; offer a general warning and
  ///     make the text editable, instead of making everything look broken.
  List<bool> get lowConfidenceFlags {
    final confidences = wordConfidences;
    final known = confidences.whereType<double>().toList()..sort();
    if (known.isEmpty) return List<bool>.filled(confidences.length, false);
    final best = known.last;
    final threshold =
        best < 0.70 ? best * 0.65 : (best - 0.18).clamp(0.45, 0.70);
    return <bool>[
      for (final confidence in confidences)
        confidence != null && confidence < threshold,
    ];
  }

  /// True when the entire utterance looks uncertain (all values low), so the
  /// reporter can fix any word but the UI does not underline the whole screen.
  bool get transcriptConfidenceLow {
    final known = wordConfidences.whereType<double>().toList()..sort();
    return known.isNotEmpty && known.last < 0.70;
  }

  bool isLowConfidence(int index) {
    final flags = lowConfidenceFlags;
    return index >= 0 && index < flags.length && flags[index];
  }

  /// Words with no metadata (typed, old server) remain editable for backwards
  /// compatibility; low-confidence/whole-sentence-uncertain words are editable;
  /// high-confidence words are read-only.
  List<bool> get wordEditability =>
      List<bool>.filled(wordConfidences.length, true);

  bool isWordEditable(int index) {
    final editable = wordEditability;
    return index >= 0 && index < editable.length && editable[index];
  }

  int get lowConfidenceCount => lowConfidenceFlags.where((flag) => flag).length;

  bool get isBusy =>
      _phase == ReporterPhase.transcribing ||
      _phase == ReporterPhase.analyzing ||
      _phase == ReporterPhase.submitting;

  // ── language ──────────────────────────────────────────────────────────────

  void setLanguage(ReporterLanguage language) {
    if (_phase == ReporterPhase.listening || language == _language) return;
    _language = language;
    _notify();
  }

  // ── voice ─────────────────────────────────────────────────────────────────

  /// Push-to-talk, finger DOWN on the mic: start recording.
  Future<void> micDown() async {
    if (_disposed) return;
    if (_phase != ReporterPhase.idle && _phase != ReporterPhase.asking) return;
    _held = true;
    _holdStart = DateTime.now();
    _listenStarted = false;
    await _beginListening();
  }

  /// Push-to-talk, finger UP: the reporter's part is over; transcribe it.
  /// A very short press is an accident: nothing is sent.
  Future<void> micUp() async {
    _held = false;
    if (_phase != ReporterPhase.listening || !_listenStarted) {
      // Released before the recorder was ready: _beginListening handles it.
      return;
    }
    await _endHold();
  }

  Future<void> _endHold() async {
    final heldFor = DateTime.now().difference(_holdStart ?? DateTime.now());
    if (heldFor < minHold) {
      _epoch++;
      await _speech.cancel();
      _fail(ReporterError.holdToTalk);
      return;
    }
    await _speech.stop();
  }

  Future<void> _beginListening() async {
    final epoch = _epoch;
    await _tts.stop();
    final ok = await _speech.initialize();
    if (_stale(epoch)) return;
    if (!ok) {
      _held = false;
      _fail(ReporterError.micUnavailable);
      return;
    }
    // Released already, or the first-time permission dialog took the press:
    // never record hands-free, nobody could stop it.
    final heldFor = DateTime.now().difference(_holdStart ?? DateTime.now());
    if (!_held || heldFor > const Duration(milliseconds: 2500)) {
      _held = false;
      _fail(ReporterError.holdToTalk);
      return;
    }
    unawaited(_refreshFix());

    _error = null;
    _errorDetail = null;
    _level = 0;
    _phase = ReporterPhase.listening;
    _notify();
    try {
      await _speech.listen(
        autoStop: false,
        language: _language,
        onLevel: (level) {
          if (_stale(epoch) || _phase != ReporterPhase.listening) return;
          _level = level;
          _notify();
        },
        onProcessing: () {
          if (_stale(epoch) || _phase != ReporterPhase.listening) return;
          _phase = ReporterPhase.transcribing;
          _notify();
        },
        onResult: (result) => _onTranscribed(epoch, result),
        onError: (message) {
          if (_stale(epoch)) return;
          _fail(ReporterError.transcribe, detail: message);
        },
      );
    } on Object {
      if (_stale(epoch)) return;
      _fail(ReporterError.micUnavailable);
      return;
    }
    if (_stale(epoch)) return;
    _listenStarted = true;
    // The finger was lifted while the recorder was still starting.
    if (!_held && _phase == ReporterPhase.listening) await _endHold();
  }

  /// Leaves the recording / transcription (e.g. before opening the menu).
  Future<void> cancelCapture() async {
    if (_phase != ReporterPhase.listening &&
        _phase != ReporterPhase.transcribing) {
      return;
    }
    _epoch++;
    _held = false;
    await _speech.cancel();
    _phase = _restingPhase();
    _notify();
  }

  void _onTranscribed(int epoch, TranscriptionResult result) {
    if (_stale(epoch)) return;
    if (_phase != ReporterPhase.listening &&
        _phase != ReporterPhase.transcribing) {
      return;
    }
    final heard = result.text.trim();
    final firstTurn = _turns.isEmpty;

    // Whisper was unusable on the initial report. Re-ask at most ONCE, then
    // hand the report to the deterministic 8×8×8 menu (emergencies must not
    // be delayed by an endless conversation).
    if (firstTurn && heard.isNotEmpty && _isUnusableTranscription(result)) {
      if (!_lowConfidenceReaskUsed) {
        unawaited(_askAgain());
        return;
      }
      unawaited(_openManualMenu());
      return;
    }

    if (heard.isEmpty) {
      if (firstTurn && _lowConfidenceReaskUsed) {
        // The second attempt produced no speech: same deterministic fallback.
        unawaited(_openManualMenu());
        return;
      }
      _fail(ReporterError.noSpeech);
      return;
    }
    _transcriptCorrected = result.corrected;
    _addUtterance(heard, transcribedWords: result.words);
  }

  bool _isUnusableTranscription(TranscriptionResult result) {
    if (result.words.isEmpty) return false;
    final probabilities = <double>[
      for (final word in result.words) word.probability,
    ];
    final best = probabilities.reduce((a, b) => a > b ? a : b);
    final veryWeak = probabilities.where((value) => value < 0.55).length;
    // A single uncertain word is fine (the UI lets the reporter edit it).
    // Only a whole cluttered/short sentence triggers a repeat.
    return best < 0.60 || veryWeak / probabilities.length >= 0.5;
  }

  Future<void> _askAgain() async {
    _lowConfidenceReaskUsed = true;
    _error = null;
    _errorDetail = null;
    _question = _language == ReporterLanguage.en
        ? "I didn't catch that clearly. Please repeat once."
        : 'Nu am înțeles bine. Poți repeta o dată?';
    _phase = ReporterPhase.asking;
    _notify();
    try {
      await _tts.speak(_question!, _language);
    } on Object {
      // TTS is optional; the on-screen prompt is enough.
    }
  }

  Future<void> _openManualMenu() async {
    _manualMenuRequested = true;
    _question = null;
    _pendingSlot = null;
    _phase = ReporterPhase.idle;
    _notify();
    final callback = onLowConfidenceMenu;
    if (callback != null) {
      try {
        await callback();
      } on Object catch (error) {
        debugPrint('[reporter] manual menu failed: $error');
      }
    }
  }

  /// Typed fallback ("Scrie în loc să vorbești"): same pipeline as voice.
  void submitText(String text) {
    final typed = text.trim();
    if (typed.isEmpty || isBusy || _disposed) return;
    _epoch++;
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    _addUtterance(typed);
  }

  void _addUtterance(
    String text, {
    List<TranscriptionWord>? transcribedWords,
  }) {
    final words = <_Word>[
      if (transcribedWords != null && transcribedWords.isNotEmpty)
        for (final word in transcribedWords)
          if (word.text.trim().isNotEmpty)
            _Word(word.text.trim(), word.probability),
    ];
    if (words.isEmpty) {
      words.addAll(
        text
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .map((word) => _Word(word, null)),
      );
    }
    if (words.isEmpty) {
      _fail(ReporterError.noSpeech);
      return;
    }
    // The answer is filed under the question that was asked, whatever it says.
    _turns.add(_Turn(_pendingSlot, words));
    _pendingSlot = null;
    _keepKnownCode = _brain.askedCount > 0;
    unawaited(_analyze());
  }

  // ── conversation ──────────────────────────────────────────────────────────

  Future<void> _analyze() async {
    final epoch = _epoch;
    _phase = ReporterPhase.analyzing;
    _error = null;
    _errorDetail = null;
    _level = 0;
    _notify();

    AnalyzeResult? server;
    String? offline;
    try {
      server = await _analyzeFn(AnalyzeRequest(
        transcript: transcript,
        hintCode: _hintCode,
        clarificationsAsked: _brain.askedCount,
        knownIncidentCode: _keepKnownCode ? _serverCode : null,
      ));
    } on ApiException catch (error) {
      offline = error.message;
    } on Object catch (error) {
      offline = error.toString();
    }
    if (_stale(epoch)) return;
    _serverCode = server?.fields.incidentCode;

    final assessment = _brain.assess(
      turns: <BrainTurn>[
        for (final turn in _turns)
          BrainTurn(
            slot: turn.slot,
            text: turn.words.map((word) => word.text).join(' '),
          ),
      ],
      server: server,
      hintCode: _hintCode,
      maxQuestions: maxQuestions,
      english: _language == ReporterLanguage.en,
    );
    _result = assessment.result;
    _details = assessment.details;
    if (offline != null) {
      // Keep going with what we understood ourselves; sending will tell the
      // reporter if the server is still unreachable.
      _error = ReporterError.aiOffline;
      _errorDetail = offline;
    }

    final next = assessment.next;
    if (next == null) {
      _question = null;
      _pendingSlot = null;
      _phase = ReporterPhase.confirming;
      _notify();
      return;
    }
    await _ask(next);
  }

  Future<void> _ask(PlannedQuestion question) async {
    _brain.markAsked(question.slot);
    _pendingSlot = question.slot;
    final inEnglish =
        _language == ReporterLanguage.en && !question.isRomanianOnly;
    final text = inEnglish ? question.en : question.ro;
    _question = text;
    _phase = ReporterPhase.asking;
    _notify();
    // Push-to-talk: after the question the reporter holds the mic to answer.
    await _tts.speak(
      text,
      inEnglish ? ReporterLanguage.en : ReporterLanguage.ro,
    );
  }

  /// "Trimite oricum": stop answering questions and review what we have.
  void skipQuestions() {
    if (_phase != ReporterPhase.asking && _phase != ReporterPhase.listening) {
      return;
    }
    _epoch++;
    _held = false;
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    _question = null;
    _pendingSlot = null;
    _phase = ReporterPhase.confirming;
    _notify();
  }

  // ── confirmation edits ────────────────────────────────────────────────────

  /// Replaces the word at [index] (empty replacement removes it) and asks the
  /// server again, so the understood fields follow the corrected text.
  void editWord(int index, String replacement) {
    if (_phase != ReporterPhase.confirming) return;
    // Enforce the accessibility/confidence rule in the controller too, not only
    // by disabling the chip: high-confidence words are read-only.
    if (!isWordEditable(index)) return;
    var offset = 0;
    for (var t = 0; t < _turns.length; t++) {
      final turn = _turns[t];
      if (index < offset + turn.words.length) {
        final local = index - offset;
        final fixed = replacement.trim();
        if (fixed.isEmpty) {
          turn.words.removeAt(local);
          if (turn.words.isEmpty) _turns.removeAt(t);
        } else {
          turn.words[local] = _Word(fixed, 1.0);
        }
        break;
      }
      offset += turn.words.length;
    }
    _keepKnownCode = false;
    _serverCode = null;
    if (_turns.isEmpty) {
      _resetConversation();
      _phase = ReporterPhase.idle;
      _notify();
      return;
    }
    unawaited(_analyze());
  }

  /// The reporter overrides the type with a menu pick while confirming.
  void pickType(IncidentType type) {
    if (_phase != ReporterPhase.confirming) return;
    _hintCode = type.code;
    _keepKnownCode = false;
    _serverCode = null;
    unawaited(_analyze());
  }

  void retryAnalyze() {
    if (_phase != ReporterPhase.confirming || _turns.isEmpty) return;
    unawaited(_analyze());
  }

  /// "Reia de la capăt": throws away the current voice + result and goes
  /// back to the mic screen, ready for a brand new recording (hold to talk).
  Future<void> restart() async {
    _epoch++;
    _held = false;
    await _speech.cancel();
    await _tts.stop();
    _resetConversation();
    _phase = ReporterPhase.idle;
    _notify();
  }

  /// Back to the empty start screen (after a sent report).
  Future<void> newReport() async {
    _epoch++;
    _held = false;
    await _speech.cancel();
    await _tts.stop();
    _resetConversation();
    _phase = ReporterPhase.idle;
    _notify();
  }

  // ── sending ───────────────────────────────────────────────────────────────

  /// Edit the ticket after it has been submitted (active tickets only).
  Future<bool> editSent({
    String? transcript,
    String? photoBase64,
  }) async {
    final current = _sent;
    final edit = editTicketFn;
    if (current == null || edit == null) return false;
    try {
      final updated = await edit(
        current.id,
        transcript: transcript,
        photoBase64: photoBase64,
      );
      _sent = updated;
      _notify();
      return true;
    } on ApiException catch (error) {
      _error = ReporterError.server;
      _errorDetail = error.message;
      _notify();
      return false;
    } on Object catch (error) {
      _error = ReporterError.server;
      _errorDetail = error.toString();
      _notify();
      return false;
    }
  }

  Future<void> submit({String? photoBase64}) async {
    if (_phase != ReporterPhase.confirming) return;
    if (_turns.isEmpty && _hintCode == null) return;
    final epoch = _epoch;
    _phase = ReporterPhase.submitting;
    _error = null;
    _errorDetail = null;
    _notify();
    try {
      final fix = _fix ?? await _location?.current();
      _fix = fix;
      final ticket = await _reportFn(ReportDraft(
        source: ReportSource.voice,
        transcript: transcript,
        reporterId: reporterId,
        reporterName: reporterName,
        location: IncidentLocation(
          zone: _result?.fields.location ?? '',
          lat: fix?.lat,
          lng: fix?.lng,
          note: _detailsNote(),
        ),
        hintCode: _hintCode,
        photoBase64: photoBase64,
        // A type the reporter picked is trusted (no AI wait); otherwise the AI
        // classifies the full transcript.
        useAi: _hintCode == null,
      ));
      if (_stale(epoch)) return;
      _sent = ticket;
      _phase = ReporterPhase.sent;
      _notify();
    } on ApiException catch (error) {
      if (_stale(epoch)) return;
      _fail(ReporterError.server,
          detail: error.message, phase: ReporterPhase.confirming);
    } on Object catch (error) {
      if (_stale(epoch)) return;
      _fail(ReporterError.server,
          detail: error.toString(), phase: ReporterPhase.confirming);
    }
  }

  /// "Dimensiune: mare; Persoane în pericol: Da" — travels in the location
  /// note so dispatchers see the details the reporter gave.
  String? _detailsNote() {
    if (_details.isEmpty) return null;
    return _details.entries
        .map((entry) => '${detailLabel(entry.key, ro: true)}: ${entry.value}')
        .join('; ');
  }

  /// Button-menu report: no questions, no AI, goes straight to the server.
  Future<void> submitMenu(
    IncidentType type, {
    String locationText = '',
    String? transcript,
    String? photoBase64,
  }) async {
    if (isBusy || _disposed) return;
    _epoch++;
    final epoch = _epoch;
    _held = false;
    await _speech.cancel();
    await _tts.stop();
    _resetConversation();
    _phase = ReporterPhase.submitting;
    _notify();
    try {
      final fix = _fix ?? await _location?.current();
      _fix = fix;
      final ticket = await _reportFn(ReportDraft(
        source: ReportSource.menu,
        transcript: transcript ?? type.labelRo,
        reporterId: reporterId,
        reporterName: reporterName,
        location: IncidentLocation(
          zone: locationText.trim(),
          lat: fix?.lat,
          lng: fix?.lng,
        ),
        hintCode: type.code,
        useAi: false,
        photoBase64: photoBase64,
      ));
      if (_stale(epoch)) return;
      _sent = ticket;
      _phase = ReporterPhase.sent;
      _notify();
    } on ApiException catch (error) {
      if (_stale(epoch)) return;
      _fail(ReporterError.server,
          detail: error.message, phase: ReporterPhase.idle);
    } on Object catch (error) {
      if (_stale(epoch)) return;
      _fail(ReporterError.server,
          detail: error.toString(), phase: ReporterPhase.idle);
    }
  }

  // ── internals ─────────────────────────────────────────────────────────────

  Future<void> _refreshFix() async {
    final location = _location;
    if (location == null) return;
    final fix = await location.current();
    if (fix != null && !_disposed) {
      _fix = fix;
      _notify();
    }
  }

  void _resetConversation() {
    _transcriptCorrected = false;
    _lowConfidenceReaskUsed = false;
    _manualMenuRequested = false;
    _turns.clear();
    _pendingSlot = null;
    _brain.reset();
    _result = null;
    _details = const <String, String>{};
    _question = null;
    _keepKnownCode = false;
    _serverCode = null;
    _hintCode = null;
    _error = null;
    _errorDetail = null;
    _sent = null;
    _level = 0;
  }

  ReporterPhase _restingPhase() {
    if (_turns.isEmpty) return ReporterPhase.idle;
    if (_question != null && _pendingSlot != null) return ReporterPhase.asking;
    return ReporterPhase.confirming;
  }

  void _fail(ReporterError error, {String? detail, ReporterPhase? phase}) {
    _error = error;
    _errorDetail = detail;
    _level = 0;
    _phase = phase ?? _restingPhase();
    _notify();
  }

  bool _stale(int epoch) => _disposed || epoch != _epoch;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    super.dispose();
  }
}
