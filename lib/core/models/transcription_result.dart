// =============================================================================
// lib/core/models/transcription_result.dart
//
// OWNER: Lead (lib/core/). Contract for the voice reporter flow.
// Mirrors `POST /api/transcribe` in `backend/app/main.py` (local faster-whisper).
//
// Flow: record a short clip -> api.transcribe(bytes) -> text -> feed that text
// into api.analyze(...) (conversation) or api.report(...) (menu/submit).
// Nothing about the classification contract changes: speech-to-text only adds
// the mic hop, and it runs on the laptop so the demo works offline.
// =============================================================================

/// Result of one speech-to-text call.
class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    this.language = '',
    this.languageProbability = 0,
    this.durationMs = 0,
    this.model = '',
    this.provider = 'faster-whisper',
    this.latencyMs = 0,
  });

  /// Transcribed text; may be empty when the clip had no speech (VAD trim).
  final String text;

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
    return TranscriptionResult(
      text: json['text'] is String ? json['text'] as String : '',
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
