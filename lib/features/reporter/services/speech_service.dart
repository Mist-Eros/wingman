// Voice capture behind a tiny interface so the controller can be tested
// without a microphone.
//
// Whisper is not a streaming recognizer: the phone records a short WAV (16 kHz
// mono), stops by itself after a pause, uploads it and gets the text back. So
// there are no live partial words — the UI shows the input level instead.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart';

import '../reporter_language.dart';
import 'whisper_transcriber.dart';

abstract class SpeechService {
  /// Asks for the microphone permission (first call). False => no microphone.
  Future<bool> initialize();

  /// Records one utterance until [stop] (push-to-talk: the reporter releases
  /// the button) — or, when [autoStop] is true, until a pause in speech.
  /// Then: [onProcessing] (upload + Whisper), and exactly one of [onResult]
  /// (text, possibly empty when nothing was said) or [onError].
  Future<void> listen({
    required ReporterLanguage language,
    required void Function(double level) onLevel,
    required void Function() onProcessing,
    required void Function(String text) onResult,
    required void Function(String message) onError,
    bool autoStop = true,
  });

  /// Ends the recording now and transcribes what was said.
  Future<void> stop();

  /// Drops the recording / pending transcription without any callback.
  Future<void> cancel();
}

typedef TranscribeFn = Future<String> Function(
  Uint8List wav,
  ReporterLanguage language,
);

class WhisperSpeechService implements SpeechService {
  WhisperSpeechService({required this.transcribe});

  final TranscribeFn transcribe;

  /// Below this input level (dBFS) the phone considers it silence. Tune on a
  /// real apron: engine noise can keep the level high, in which case the
  /// manual stop button and [_maxRecording] still end the take.
  static const double _speechDb = -38;
  static const Duration _pauseAfterSpeech = Duration(milliseconds: 1600);
  static const Duration _noSpeechTimeout = Duration(seconds: 8);
  // The server recommends 5-15 s clips; beyond ~20 s the latency grows.
  static const Duration _maxRecording = Duration(seconds: 30);

  /// Anything shorter than this is just a click (16 kHz * 2 bytes * ~0.15 s).
  static const int _minBytes = 6000;

  final AudioRecorder _recorder = AudioRecorder();

  int _session = 0;
  bool _finishing = false;
  StreamSubscription<Amplitude>? _amplitude;
  File? _file;
  ReporterLanguage _language = ReporterLanguage.ro;
  void Function()? _onProcessing;
  void Function(String text)? _onResult;
  void Function(String message)? _onError;

  @override
  Future<bool> initialize() async {
    try {
      return await _recorder.hasPermission();
    } on Object {
      return false;
    }
  }

  @override
  Future<void> listen({
    required ReporterLanguage language,
    required void Function(double level) onLevel,
    required void Function() onProcessing,
    required void Function(String text) onResult,
    required void Function(String message) onError,
    bool autoStop = true,
  }) async {
    await _dropRecording();
    final session = ++_session;
    _finishing = false;
    _language = language;
    _onProcessing = onProcessing;
    _onResult = onResult;
    _onError = onError;

    final file = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'wingman_${DateTime.now().microsecondsSinceEpoch}.wav',
    );
    _file = file;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: file.path,
    );

    final startedAt = DateTime.now();
    var lastSpeechAt = startedAt;
    var heardSpeech = false;
    _amplitude = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 150))
        .listen((amplitude) {
      if (session != _session) return;
      final now = DateTime.now();
      final db = amplitude.current;
      onLevel(((db + 55) / 55).clamp(0.0, 1.0));
      if (db > _speechDb) {
        heardSpeech = true;
        lastSpeechAt = now;
      }
      final total = now.difference(startedAt);
      final silentFor = now.difference(lastSpeechAt);
      if (total > _maxRecording ||
          (autoStop &&
              ((heardSpeech && silentFor > _pauseAfterSpeech) ||
                  (!heardSpeech && total > _noSpeechTimeout)))) {
        unawaited(_finish(session));
      }
    });
  }

  @override
  Future<void> stop() => _finish(_session);

  Future<void> _finish(int session) async {
    if (session != _session || _finishing) return;
    _finishing = true;
    await _amplitude?.cancel();
    _amplitude = null;

    String? path;
    try {
      path = await _recorder.stop();
    } on Object {
      path = null;
    }
    if (session != _session) return;
    final file = File(path ?? _file?.path ?? '');
    _onProcessing?.call();

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on Object {
      bytes = Uint8List(0);
    } finally {
      unawaited(_delete(file));
    }
    if (session != _session) return;
    if (bytes.length < _minBytes) {
      _onResult?.call('');
      return;
    }

    try {
      final text = await transcribe(bytes, _language);
      if (session != _session) return;
      _onResult?.call(text.trim());
    } on TranscribeException catch (error) {
      if (session != _session) return;
      _onError?.call(error.message);
    } on Object catch (error) {
      if (session != _session) return;
      _onError?.call('Transcrierea a eșuat: $error');
    }
  }

  @override
  Future<void> cancel() async {
    _session++;
    _finishing = false;
    _onProcessing = null;
    _onResult = null;
    _onError = null;
    await _dropRecording();
  }

  Future<void> _dropRecording() async {
    await _amplitude?.cancel();
    _amplitude = null;
    try {
      if (await _recorder.isRecording()) await _recorder.cancel();
    } on Object {
      // already stopped
    }
    final file = _file;
    _file = null;
    if (file != null) unawaited(_delete(file));
  }

  Future<void> _delete(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // temp file, the OS will clean it up
    }
  }
}
