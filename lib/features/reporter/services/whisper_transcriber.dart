// Sends a recorded WAV to the laptop (local faster-whisper) and returns the
// transcript. This is a thin wrapper over core's `ApiClient.transcribe`
// (docs/whisper-contract.md): same TLS pinning, same bearer token, same
// friendly ApiException messages — the reporter only turns failures into its
// own TranscribeException so the push-to-talk flow can show them.

import 'dart:typed_data';

import '../../../core/api/api_client.dart';
import '../../../core/models/transcription_result.dart';
import '../reporter_language.dart';

class TranscribeException implements Exception {
  TranscribeException(this.message);

  final String message;

  @override
  String toString() => 'TranscribeException: $message';
}

class WhisperTranscriber {
  WhisperTranscriber(this._api);

  final ApiClient _api;

  /// [wav] is a 16 kHz mono WAV. The language is the one picked with the
  /// RO/EN toggle: forcing it avoids Whisper guessing wrong on a short phrase.
  /// Empty text means the clip had no speech (the server's VAD trimmed it).
  Future<TranscriptionResult> transcribe(
    Uint8List wav,
    ReporterLanguage language,
  ) async {
    try {
      return await _api.transcribe(
        wav,
        mimeType: 'audio/wav',
        language: language.code,
      );
    } on ApiException catch (error) {
      throw TranscribeException(_friendly(error));
    }
  }

  String _friendly(ApiException error) {
    switch (error.statusCode) {
      case 503:
        return 'Modelul Whisper nu e încă pregătit pe server. Folosește '
            'meniul sau scrie textul.';
      case 400:
        return 'Serverul nu a putut citi înregistrarea. Încearcă din nou.';
      default:
        return error.message;
    }
  }
}
