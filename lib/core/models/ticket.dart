// =============================================================================
// lib/core/models/ticket.dart
//
// OWNER: Lead (lib/core/). FROZEN WIRE CONTRACT — matches `backend/app/store.py`
// field-for-field. Every JSON key below is snake_case and is asserted by
// `scripts/check_wire_parity.py`. If you need a new field, add it on BOTH
// sides (`Ticket.toJson` / `fromJson` here + `_ticket_wire` in store.py) and
// run that script — never patch one side only.
//
// Status lifecycle (server is the only writer):
//
//   POST /api/reports
//        │
//        ├─ confidence >= threshold ─────────────────────────► dispatched
//        └─ confidence <  threshold ──► pending_override ──┬──► dispatched  (confirm)
//                                        │ 5 s deadline     ├──► denied     (deny)
//                                        │                  └──► dispatched  (override code)
//                                        └── timer expires ────► dispatched (auto, "no dispatcher")
//
//   dispatched ──first crew joins──► in_progress ──quorum approve votes──► resolved
//   any active ticket ──dispatcher deny──► denied
// =============================================================================

import '../incidents/taxonomy.dart';
import '../incidents/likelihood.dart';

/// How the report entered the system.
enum ReportSource {
  voice('voice', 'Mesaj vocal'),
  menu('menu', 'Meniu de butoane');

  const ReportSource(this.wire, this.labelRo);

  final String wire;
  final String labelRo;

  static ReportSource fromWire(String value) {
    for (final source in ReportSource.values) {
      if (source.wire == value.trim().toLowerCase()) return source;
    }
    throw FormatException('Unknown ReportSource "$value"');
  }
}

/// Who produced the classification.
enum AiSource {
  /// A real Ollama call answered.
  ollama('ollama', 'AI (Ollama)'),

  /// Ollama was down / timed out / returned junk; deterministic keyword
  /// classifier answered. Always low confidence → dispatcher override path.
  fallback('fallback', 'Fallback determinist'),

  /// Reporter picked the type from the button menu; AI was not asked.
  manual('manual', 'Selectat manual');

  const AiSource(this.wire, this.labelRo);

  final String wire;
  final String labelRo;

  static AiSource fromWire(String value) {
    for (final source in AiSource.values) {
      if (source.wire == value.trim().toLowerCase()) return source;
    }
    throw FormatException('Unknown AiSource "$value"');
  }
}

/// Ticket lifecycle. Wire values are part of the contract.
enum TicketStatus {
  /// Low AI confidence: the dispatcher has a 5-second window to confirm,
  /// deny or re-classify before the ticket auto-dispatches.
  pendingOverride(
    'pending_override',
    'Așteaptă dispecerul',
    'Awaiting dispatcher',
    0,
  ),

  /// Broadcast to the responsible departments.
  dispatched('dispatched', 'Dispecerizat', 'Dispatched', 1),

  /// At least one crew member joined and is working on it.
  inProgress('in_progress', 'În lucru', 'In progress', 2),

  /// Crew vote quorum reached; a high/critical incident still needs the
  /// dispatcher/admin to confirm the resolution.
  pendingResolution(
    'pending_resolution',
    'Așteaptă confirmarea',
    'Awaiting confirmation',
    3,
  ),

  /// Crew vote quorum reached (or the dispatcher confirmed it).
  resolved('resolved', 'Rezolvat', 'Resolved', 4),

  /// Dispatcher rejected the classification.
  denied('denied', 'Respins', 'Denied', 5);

  const TicketStatus(this.wire, this.labelRo, this.labelEn, this.sortOrder);

  final String wire;
  final String labelRo;
  final String labelEn;

  /// Dispatcher dashboard ordering (pending override first).
  final int sortOrder;

  bool get isActive =>
      this == TicketStatus.pendingOverride ||
      this == TicketStatus.dispatched ||
      this == TicketStatus.inProgress ||
      this == TicketStatus.pendingResolution;

  bool get isTerminal =>
      this == TicketStatus.resolved || this == TicketStatus.denied;

  static TicketStatus fromWire(String value) {
    final parsed = tryFromWire(value);
    if (parsed == null) {
      throw FormatException(
        'Unknown TicketStatus "$value". '
        'Expected one of: ${TicketStatus.values.map((s) => s.wire).join(", ")}',
      );
    }
    return parsed;
  }

  static TicketStatus? tryFromWire(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final status in TicketStatus.values) {
      if (status.wire == normalized) return status;
    }
    return null;
  }
}

/// Where the incident is. Sent by the reporter app; shows on both dashboards.
class IncidentLocation {
  const IncidentLocation({
    this.terminal = '',
    this.zone = '',
    this.lat,
    this.lng,
    this.note,
  });

  /// e.g. "T1".
  final String terminal;

  /// e.g. "Schengen · Poarta 12".
  final String zone;

  final double? lat;
  final double? lng;

  /// Free text, e.g. "lângă banda 3".
  final String? note;

  bool get isEmpty => terminal.trim().isEmpty && zone.trim().isEmpty;

  /// "T1 · Poarta 12" or a friendly placeholder.
  String get display {
    final parts = <String>[
      if (terminal.trim().isNotEmpty) terminal.trim(),
      if (zone.trim().isNotEmpty) zone.trim(),
    ];
    if (parts.isEmpty) return 'Locație nespecificată';
    return parts.join(' · ');
  }

  IncidentLocation copyWith({
    String? terminal,
    String? zone,
    double? lat,
    double? lng,
    String? note,
  }) =>
      IncidentLocation(
        terminal: terminal ?? this.terminal,
        zone: zone ?? this.zone,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'terminal': terminal,
        'zone': zone,
        'lat': lat,
        'lng': lng,
        'note': note,
      };

  factory IncidentLocation.fromJson(Object? value) {
    if (value is! Map) return const IncidentLocation();
    return IncidentLocation(
      terminal: _asStringOrEmpty(value['terminal']),
      zone: _asStringOrEmpty(value['zone']),
      lat: _asNullableDouble(value['lat']),
      lng: _asNullableDouble(value['lng']),
      note: _asStringOrNull(value['note']),
    );
  }

  @override
  String toString() => 'IncidentLocation($display)';
}

/// A persisted incident. Immutable: the server is the only writer, so the app
/// replaces whole instances whenever a WSS event arrives (see `TicketBoard`).
class Ticket {
  const Ticket({
    required this.id,
    required this.incidentCode,
    required this.labelRo,
    required this.category,
    required this.urgency,
    required this.status,
    required this.source,
    required this.reporterId,
    required this.reporterName,
    this.reportCount = 1,
    this.reporterIds = const <String>[],
    this.reporterNames = const <String>[],
    required this.transcript,
    this.photoBase64,
    required this.location,
    required this.confidence,
    required this.aiSource,
    required this.primaryDepartments,
    required this.standbyDepartments,
    required this.createdAt,
    required this.updatedAt,
    this.aiRationale,
    this.joinedCrewIds = const <String>[],
    this.joinedDepartments = const <String>[],
    this.resolveVotes = 0,
    this.resolveVoterIds = const <String>[],
    this.quorum = 2,
    this.overrideDeadline,
    this.dispatchedAt,
    this.resolvedAt,
    this.resolutionNote,
    this.decidedBy,
    this.version = 1,
  });

  /// Server-generated UUID.
  final String id;

  /// One of [IncidentTaxonomy.codes].
  final String incidentCode;

  /// Snapshot of the Romanian label at creation time (so old tickets keep
  /// rendering even if the taxonomy wording changes later).
  final String labelRo;

  final IncidentCategory category;
  final Urgency urgency;
  final TicketStatus status;
  final ReportSource source;

  final String reporterId;
  final String reporterName;

  /// Number of submissions merged into this ticket (initial report = 1).
  final int reportCount;

  /// Distinct reporter ids; a duplicate report increments [reportCount] and adds
  /// its reporter here instead of creating a second ticket.
  final List<String> reporterIds;
  final List<String> reporterNames;

  /// People who reported this incident (at least one, including legacy tickets).
  int get reporterPeopleCount => reporterIds.isEmpty ? 1 : reporterIds.length;

  /// Verbatim STT transcript for voice reports, or the menu label text.
  final String transcript;

  /// Optional base64 JPEG/PNG attached by the reporter.
  final String? photoBase64;

  final IncidentLocation location;

  /// 0.0 – 1.0 from the classifier.
  final double confidence;

  final AiSource aiSource;

  /// Short Romanian explanation from the model (dashboard tooltip).
  final String? aiRationale;

  final List<Department> primaryDepartments;
  final List<Department> standbyDepartments;

  /// Crew members who joined. The crew screen disables "Join" if `contains(me)`.
  final List<String> joinedCrewIds;

  /// Parallel to [joinedCrewIds]; one responder per primary department.
  final List<String> joinedDepartments;

  /// Number of approving resolve votes.
  final int resolveVotes;

  /// Who already voted (prevents double-tap double-count).
  final List<String> resolveVoterIds;

  /// Approvals needed to resolve.
  final int quorum;

  /// Set only while [status] == pendingOverride: end of the 5-second window.
  final DateTime? overrideDeadline;

  final DateTime? dispatchedAt;
  final DateTime? resolvedAt;
  final String? resolutionNote;

  /// Dispatcher id that confirmed/denied/overrode (null = auto-dispatch).
  final String? decidedBy;

  /// Monotonic server revision; clients may use it to ignore out-of-order
  /// events.
  final int version;

  /// Server timestamps (UTC). Used for sorting and "acum 2 min" chips.
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Derived helpers used by all three feature teams ──────────────────────

  bool get isPendingOverride => status == TicketStatus.pendingOverride;

  /// Orange/red tickets need a final dispatcher check before resolution.
  bool get requiresResolutionConfirmation =>
      status == TicketStatus.pendingResolution;

  bool get hasOverrideDeadline => overrideDeadline != null;

  /// Whole seconds left in the override window (0 when expired / not pending).
  int remainingOverrideSeconds({DateTime? now}) {
    final deadline = overrideDeadline;
    if (deadline == null) return 0;
    final remainingMs =
        deadline.difference(now ?? DateTime.now().toUtc()).inMilliseconds;
    if (remainingMs <= 0) return 0;
    return (remainingMs / 1000).ceil();
  }

  /// Confidence rendered as "87%" (model certainty, kept for diagnostics).
  String get confidenceLabel => '${(confidence * 100).round()}%';

  /// Likelihood that this incident can actually happen at Craiova airport.
  double get craiovaLikelihood => airportLikelihoodOf(
        incidentCode: incidentCode,
        location: location.display,
        urgency: urgency,
      );

  String get likelihoodLabel => airportLikelihoodPercent(craiovaLikelihood);

  bool isJoinedBy(String crewId) => joinedCrewIds.contains(crewId);

  bool hasVotedBy(String crewId) => resolveVoterIds.contains(crewId);

  Department? get primaryDepartment =>
      primaryDepartments.isEmpty ? null : primaryDepartments.first;

  String get departmentsLabel => primaryDepartments.isEmpty
      ? 'Fără departament'
      : primaryDepartments.map((d) => d.labelRo).join(' · ');

  /// Seconds since creation (for the dashboard "acum 2 min" chip).
  int ageSeconds({DateTime? now}) =>
      (now ?? DateTime.now().toUtc()).difference(createdAt).inSeconds;

  // ── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'incident_code': incidentCode,
        'label_ro': labelRo,
        'category': category.wire,
        'urgency': urgency.wire,
        'status': status.wire,
        'source': source.wire,
        'reporter_id': reporterId,
        'reporter_name': reporterName,
        'report_count': reportCount,
        'reporter_ids': List<String>.of(reporterIds),
        'reporter_names': List<String>.of(reporterNames),
        'transcript': transcript,
        'photo_base64': photoBase64,
        'location': location.toJson(),
        'confidence': confidence,
        'ai_source': aiSource.wire,
        'ai_rationale': aiRationale,
        'primary_departments':
            primaryDepartments.map((d) => d.wire).toList(growable: false),
        'standby_departments':
            standbyDepartments.map((d) => d.wire).toList(growable: false),
        'joined_crew_ids': List<String>.of(joinedCrewIds),
        'joined_departments': List<String>.of(joinedDepartments),
        'resolve_votes': resolveVotes,
        'resolve_voter_ids': List<String>.of(resolveVoterIds),
        'quorum': quorum,
        'override_deadline': _dateToWire(overrideDeadline),
        'dispatched_at': _dateToWire(dispatchedAt),
        'resolved_at': _dateToWire(resolvedAt),
        'resolution_note': resolutionNote,
        'decided_by': decidedBy,
        'created_at': _dateToWire(createdAt),
        'updated_at': _dateToWire(updatedAt),
        'version': version,
      };

  factory Ticket.fromJson(Map<String, dynamic> json) {
    final id = _asString(json['id'], 'id');
    return Ticket(
      id: id,
      incidentCode: _asString(json['incident_code'], 'incident_code'),
      labelRo: _asString(json['label_ro'], 'label_ro'),
      category:
          IncidentCategory.fromWire(_asString(json['category'], 'category')),
      urgency: Urgency.fromWire(_asString(json['urgency'], 'urgency')),
      status: TicketStatus.fromWire(_asString(json['status'], 'status')),
      source: ReportSource.fromWire(_asString(json['source'], 'source')),
      reporterId: _asString(json['reporter_id'], 'reporter_id'),
      reporterName: _asString(json['reporter_name'], 'reporter_name'),
      reportCount: _asInt(json['report_count'] ?? 1, 'report_count'),
      reporterIds: _strings(json['reporter_ids']),
      reporterNames: _strings(json['reporter_names']),
      transcript: _asString(json['transcript'], 'transcript'),
      photoBase64: _asStringOrNull(json['photo_base64']),
      location: IncidentLocation.fromJson(json['location']),
      confidence: _asDouble(json['confidence'], 'confidence'),
      aiSource: AiSource.fromWire(_asString(json['ai_source'], 'ai_source')),
      aiRationale: _asStringOrNull(json['ai_rationale']),
      primaryDepartments:
          _departments(json['primary_departments'], 'primary_departments'),
      standbyDepartments:
          _departments(json['standby_departments'], 'standby_departments'),
      joinedCrewIds: _strings(json['joined_crew_ids']),
      resolveVotes: _asInt(json['resolve_votes'] ?? 0, 'resolve_votes'),
      resolveVoterIds: _strings(json['resolve_voter_ids']),
      quorum: _asInt(json['quorum'] ?? 2, 'quorum'),
      overrideDeadline: _asDate(json['override_deadline']),
      dispatchedAt: _asDate(json['dispatched_at']),
      resolvedAt: _asDate(json['resolved_at']),
      resolutionNote: _asStringOrNull(json['resolution_note']),
      decidedBy: _asStringOrNull(json['decided_by']),
      createdAt: _asDate(json['created_at']) ?? DateTime.now().toUtc(),
      updatedAt: _asDate(json['updated_at']) ?? DateTime.now().toUtc(),
      version: _asInt(json['version'] ?? 1, 'version'),
    );
  }

  Ticket copyWith({
    TicketStatus? status,
    Urgency? urgency,
    String? incidentCode,
    String? labelRo,
    IncidentCategory? category,
    int? reportCount,
    List<String>? reporterIds,
    List<String>? reporterNames,
    List<Department>? primaryDepartments,
    List<Department>? standbyDepartments,
    List<String>? joinedCrewIds,
    List<String>? joinedDepartments,
    int? resolveVotes,
    List<String>? resolveVoterIds,
    int? quorum,
    Object? overrideDeadline = _unset,
    Object? dispatchedAt = _unset,
    Object? resolvedAt = _unset,
    Object? resolutionNote = _unset,
    Object? decidedBy = _unset,
    DateTime? updatedAt,
    int? version,
  }) =>
      Ticket(
        id: id,
        incidentCode: incidentCode ?? this.incidentCode,
        labelRo: labelRo ?? this.labelRo,
        category: category ?? this.category,
        urgency: urgency ?? this.urgency,
        status: status ?? this.status,
        source: source,
        reporterId: reporterId,
        reporterName: reporterName,
        reportCount: reportCount ?? this.reportCount,
        reporterIds: reporterIds ?? this.reporterIds,
        reporterNames: reporterNames ?? this.reporterNames,
        transcript: transcript,
        location: location,
        confidence: confidence,
        aiSource: aiSource,
        aiRationale: aiRationale,
        primaryDepartments: primaryDepartments ?? this.primaryDepartments,
        standbyDepartments: standbyDepartments ?? this.standbyDepartments,
        joinedCrewIds: joinedCrewIds ?? this.joinedCrewIds,
        joinedDepartments: joinedDepartments ?? this.joinedDepartments,
        resolveVotes: resolveVotes ?? this.resolveVotes,
        resolveVoterIds: resolveVoterIds ?? this.resolveVoterIds,
        quorum: quorum ?? this.quorum,
        overrideDeadline: identical(overrideDeadline, _unset)
            ? this.overrideDeadline
            : overrideDeadline as DateTime?,
        dispatchedAt: identical(dispatchedAt, _unset)
            ? this.dispatchedAt
            : dispatchedAt as DateTime?,
        resolvedAt: identical(resolvedAt, _unset)
            ? this.resolvedAt
            : resolvedAt as DateTime?,
        resolutionNote: identical(resolutionNote, _unset)
            ? this.resolutionNote
            : resolutionNote as String?,
        decidedBy: identical(decidedBy, _unset)
            ? this.decidedBy
            : decidedBy as String?,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        version: version ?? this.version,
      );

  @override
  String toString() => 'Ticket($id, $incidentCode, ${status.wire})';

  static const Object _unset = Object();
}

/// What the reporter app POSTs to `/api/reports`.
///
/// Voice flow: `source: voice, transcript: "<STT text>", useAi: true`.
/// Menu flow:  `source: menu,  hintCode: "<code from taxonomy>"` — the server
/// trusts the user's pick (confidence 1.0, `manual`) unless `useAi: true`.
class ReportDraft {
  const ReportDraft({
    required this.source,
    required this.transcript,
    required this.reporterId,
    required this.reporterName,
    this.location = const IncidentLocation(),
    this.hintCode,
    this.useAi = true,
    this.forceOverride = false,
    this.photoBase64,
  });

  final ReportSource source;
  final String transcript;
  final String reporterId;
  final String reporterName;
  final IncidentLocation location;

  /// Set when the user picked an incident type from the button menu.
  final String? hintCode;

  /// Force the AI even when [hintCode] is set (used by the "verify" toggle).
  final bool useAi;

  /// Optional base64 JPEG/PNG attached by the reporter.
  final String? photoBase64;

  /// DEV/DEMO ONLY (DevTools + rehearsals): forces the server to cap
  /// confidence and take the 5-second dispatcher override path. The normal
  /// reporter flow never sets it.
  final bool forceOverride;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'source': source.wire,
        'transcript': transcript,
        'reporter_id': reporterId,
        'reporter_name': reporterName,
        'location': location.toJson(),
        'hint_code': hintCode,
        'use_ai': useAi,
        if (photoBase64 != null) 'photo_base64': photoBase64,
        // Only serialized when enabled so the normal wire body stays byte-for-
        // byte identical to the frozen contract.
        if (forceOverride) 'force_override': true,
      };
}

// ── Small, explicit parsing helpers (clear errors beat silent nulls) ────────

String _asString(Object? value, String field) {
  if (value is String) return value;
  throw FormatException(
    'Ticket field "$field": expected String, got ${value.runtimeType} ($value)',
  );
}

String? _asStringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

String _asStringOrEmpty(Object? value) => value is String ? value : '';

int _asInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException(
    'Ticket field "$field": expected int, got ${value.runtimeType} ($value)',
  );
}

double _asDouble(Object? value, String field) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException(
    'Ticket field "$field": expected number, got ${value.runtimeType} ($value)',
  );
}

double? _asNullableDouble(Object? value) =>
    value is num ? value.toDouble() : null;

DateTime? _asDate(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed.toUtc();
  }
  return null;
}

String? _dateToWire(DateTime? value) =>
    value == null ? null : value.toUtc().toIso8601String();

List<String> _strings(Object? value) {
  if (value is! List) return const <String>[];
  return List<String>.unmodifiable(
    <String>[
      for (final item in value)
        if (item is String) item
    ],
  );
}

List<Department> _departments(Object? value, String field) {
  if (value == null) return const <Department>[];
  if (value is! List) {
    throw FormatException(
      'Ticket field "$field": expected List, got ${value.runtimeType}',
    );
  }
  return List<Department>.unmodifiable(<Department>[
    for (final item in value)
      if (item is String) Department.fromWire(item),
  ]);
}
