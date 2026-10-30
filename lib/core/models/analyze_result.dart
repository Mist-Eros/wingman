// =============================================================================
// lib/core/models/analyze_result.dart
//
// OWNER: Lead (lib/core/). FROZEN CONTRACT for the conversational reporter flow
// (rarescu08). Mirrors `POST /api/analyze` in `backend/app/main.py`.
//
// One turn of the conversation:
//   1. Reporter app records/collects text into `transcript`.
//   2. POST /api/analyze with the accumulated transcript + `clarificationsAsked`.
//   3. Show AND speak `result.question` (null => done).
//   4. Append the answer to the transcript, re-POST with the counter + 1.
//   5. When `result.ready` is true, submit via `api.report(...)`; the ticket
//      will carry the classification and (if still uncertain) land in the
//      dispatcher's 5-second override window automatically.
//
// Rules the server enforces (do not duplicate them in the UI):
//   • at most `maxClarifications` questions (3);
//   • after that, `question` is null and `fields.confidence` is capped at 0.40
//     so the ticket goes to the dispatcher;
//   • the button menu is always a valid fallback (no questions, no AI wait).
// =============================================================================

import '../incidents/taxonomy.dart';
import 'ticket.dart';

/// Request body for one `/api/analyze` turn.
class AnalyzeRequest {
  const AnalyzeRequest({
    required this.transcript,
    this.location = const IncidentLocation(),
    this.hintCode,
    this.clarificationsAsked = 0,
    this.knownIncidentCode,
  });

  /// Everything said so far (all turns concatenated, in order).
  final String transcript;

  final IncidentLocation location;

  /// Set when the user picked the type from the menu (bypasses the type slot).
  final String? hintCode;

  /// How many clarification questions the app already asked (server stops at 3).
  final int clarificationsAsked;

  /// Optional: the code confirmed in an earlier turn (sent back by the server
  /// in `fields.incident_code`), so a later turn does not lose it.
  final String? knownIncidentCode;

  /// Exact `/api/analyze` body — mirrors `backend/app/schemas.py::AnalyzeIn`
  /// (`extra="forbid"`: do not add fields the server does not declare).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'transcript': transcript,
        'location': location.toJson(),
        'hint_code': hintCode,
        'clarifications_asked': clarificationsAsked,
        'known_incident_code': knownIncidentCode,
      };
}

/// Slots extracted from the conversation so far.
class AnalyzeFields {
  const AnalyzeFields({
    this.incidentCode,
    this.labelRo,
    this.location = '',
    this.peopleAtRisk,
    this.urgency = Urgency.medium,
    this.confidence = 0,
    this.aiSource = AiSource.fallback,
    this.rationale,
  });

  /// Taxonomy code, or null when the type is still unknown.
  final String? incidentCode;

  /// Romanian label of [incidentCode], or null.
  final String? labelRo;

  /// Free-text location ("Poarta 12", "T1 · Poarta 12", ...), or "".
  final String location;

  /// Whether someone is in danger: true / false / null (unknown).
  final bool? peopleAtRisk;

  final Urgency urgency;
  final double confidence;
  final AiSource aiSource;
  final String? rationale;

  /// Resolved taxonomy entry when the code is known.
  IncidentType? get incidentType =>
      incidentCode == null ? null : IncidentTaxonomy.byCode(incidentCode!);

  String get confidenceLabel => '${(confidence * 100).round()}%';

  factory AnalyzeFields.fromJson(Object? value) {
    if (value is! Map) return const AnalyzeFields();
    return AnalyzeFields(
      incidentCode: _stringOrNull(value['incident_code']),
      labelRo: _stringOrNull(value['label_ro']),
      location: _stringOrEmpty(value['location']),
      peopleAtRisk: value['people_at_risk'] is bool
          ? value['people_at_risk'] as bool
          : null,
      urgency:
          Urgency.tryFromWire(value['urgency'] as String?) ?? Urgency.medium,
      confidence: _double(value['confidence']),
      aiSource: _aiSource(value['ai_source']),
      rationale: _stringOrNull(value['rationale']),
    );
  }
}

/// One server reply from `/api/analyze`.
class AnalyzeResult {
  const AnalyzeResult({
    required this.fields,
    this.missing = const <String>[],
    this.question,
    this.clarificationsAsked = 0,
    this.maxClarifications = 3,
    this.ready = false,
    this.taxonomyVersion,
  });

  final AnalyzeFields fields;

  /// Slots the server still needs: `incident_code`, `location`, ...
  final List<String> missing;

  /// Next question to display + speak, or null when the conversation is done.
  final String? question;

  final int clarificationsAsked;
  final int maxClarifications;
  final bool ready;
  final int? taxonomyVersion;

  bool get needsMoreInfo => question != null && question!.isNotEmpty;
  bool get asksForLocation => missing.contains('location');
  bool get asksForType => missing.contains('incident_code');

  /// Human-readable summary for the "what I understood" card.
  String get summary {
    final parts = <String>[
      if (fields.labelRo != null) fields.labelRo!,
      if (fields.location.isNotEmpty) fields.location,
      'urgență ${fields.urgency.labelRo.toLowerCase()}',
      'încredere ${fields.confidenceLabel}',
    ];
    return parts.join(' · ');
  }

  factory AnalyzeResult.fromJson(Map<String, dynamic> json) {
    final missingRaw = json['missing'];
    final missing = <String>[
      if (missingRaw is List)
        for (final item in missingRaw)
          if (item is String) item,
    ];
    return AnalyzeResult(
      fields: AnalyzeFields.fromJson(json['fields']),
      missing: List<String>.unmodifiable(missing),
      question: _stringOrNull(json['question']),
      clarificationsAsked: _int(json['clarifications_asked']),
      maxClarifications: _int(json['max_clarifications'], fallback: 3),
      ready: json['ready'] == true || _stringOrNull(json['question']) == null,
      taxonomyVersion: json['taxonomy_version'] is int
          ? json['taxonomy_version'] as int
          : null,
    );
  }
}

// ── tiny parsers ─────────────────────────────────────────────────────────────

String? _stringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

String _stringOrEmpty(Object? value) => value is String ? value : '';

double _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

int _int(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

AiSource _aiSource(Object? value) {
  if (value is String) {
    for (final source in AiSource.values) {
      if (source.wire == value) return source;
    }
  }
  return AiSource.fallback;
}

