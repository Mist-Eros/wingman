// =============================================================================
// lib/core/models/transcription_result.dart
//
// Contract for POST /api/transcribe (local faster-whisper).
//
// faster-whisper's `text` has no confidence. With word_timestamps=True each
// word carries a `probability`; we expose those so the reporter screen can
// underline only the uncertain words and let the reporter correct those.
// =============================================================================

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    this.words = const <TranscriptionWord>[],
    this.language = '',
    this.languageProbability = 0,
    this.durationMs = 0,
    this.model = '',
    this.provider = 'faster-whisper',
    this.latencyMs = 0,
  });

  /// Transcribed text; may be empty when the clip had no speech (VAD trim).
  final String text;

  /// Per-word recognition metadata. Empty when the server/model does not
  /// support word timestamps (clients must keep the old editable-all fallback).
  final List<TranscriptionWord> words;

  /// Detected/forced language code (`ro`, `en`, ...), or "" when unknown.
  final String language;

  /// Whisper's confidence in [language], 0..1.
  final double languageProbability;

  /// Audio duration reported by the decoder, in milliseconds.
  final int durationMs;

  /// Model used server-side (`tiny`, `base`, `small`, ...).
  final String model;

  final String provider;

  /// Server-side transcription time, excluding upload.
  final int latencyMs;

  bool get isEmpty => text.trim().isEmpty;

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    final rawWords = json['words'];
    final words = <TranscriptionWord>[
      if (rawWords is List)
        for (final raw in rawWords)
          if (raw is Map<String, dynamic>) TranscriptionWord.fromJson(raw),
    ];
    return TranscriptionResult(
      text: json['text'] is String ? json['text'] as String : '',
      words: words,
      language: json['language'] is String ? json['language'] as String : '',
      languageProbability: _double(json['language_probability']),
      durationMs: _int(json['duration_ms']),
      model: json['model'] is String ? json['model'] as String : '',
      provider: json['provider'] is String
          ? json['provider'] as String
          : 'faster-whisper',
      latencyMs: _int(json['latency_ms']),
    );
  }
}

/// One word returned by Whisper. [probability] is 0..1; lower means the model
/// was less sure — exactly the part the reporter should be able to fix.
class TranscriptionWord {
  const TranscriptionWord({
    required this.text,
    required this.probability,
    this.start = 0,
    this.end = 0,
  });

  final String text;
  final double probability;
  final double start;
  final double end;

  bool get isLowConfidence => probability < 0.70;

  factory TranscriptionWord.fromJson(Map<String, dynamic> json) {
    return TranscriptionWord(
      text: json['text'] is String ? json['text'] as String : '',
      probability: _double(json['probability']),
      start: _double(json['start']),
      end: _double(json['end']),
    );
  }
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
