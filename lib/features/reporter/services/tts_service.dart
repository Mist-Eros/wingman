// Text-to-speech behind a tiny interface (testable). Never throws: if the
// device has no TTS voice the app simply stays silent and shows the text.

import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import '../reporter_language.dart';

abstract class TtsService {
  /// Speaks [text] and completes when finished (or after a safety timeout).
  Future<void> speak(String text, ReporterLanguage language);

  Future<void> stop();
}

class FlutterTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _configured = false;

  Future<void> _configure() async {
    if (_configured) return;
    _configured = true;
    try {
      await _tts.awaitSpeakCompletion(true);
    } on Object {
      // not supported on this platform
    }
  }

  @override
  Future<void> speak(String text, ReporterLanguage language) async {
    try {
      await _configure();
      await _tts.setLanguage(language.ttsTag);
      await _tts.speak(text).timeout(const Duration(seconds: 20));
    } on Object {
      // silent fallback: the question is on screen anyway
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object {
      // ignore
    }
  }
}
