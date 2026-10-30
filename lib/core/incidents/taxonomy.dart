// =============================================================================
// lib/core/incidents/taxonomy.dart
//
// OWNER: Lead (lib/core/). FROZEN CONTRACT — features (reporter / dispatcher /
// crew) only IMPORT from here. They never append, mutate or reorder types.
//
// This file is the SINGLE SOURCE OF TRUTH for the closed incident taxonomy.
// The backend copy (`backend/taxonomy.json`) is GENERATED from this file, so
// the Flutter app and the Ollama prompt can never drift apart.
//
// ─────────────────────────────────────────────────────────────────────────────
//  HOW TO SWAP IN THE REAL TAXONOMY DOC (≈10 minutes)
//  1. Replace ONLY the 14 entries inside `IncidentTaxonomy.all` below.
//  2. If your doc names departments we don't have, add them to the
//     `Department` enum (wire = snake_case, labelRo = Romanian display text).
//  3. Keep these argument names: code, labelRo, category, urgency,
//     primaryDepartments, standbyDepartments. Keep 14 types / 4 categories.
//  4. Re-emit the backend copy (do this every time `all` changes):
//       dart run tool/emit_taxonomy.dart
//     or, on the laptop, with Python installed:
//       python scripts/sync_taxonomy.py --write
//     `scripts/sync_taxonomy.py` also FAILS if this file and the JSON differ,
//     so a teammate can't silently break the AI contract.
//  5. Nothing else in the app changes: all UI reads types by `code`.
// ─────────────────────────────────────────────────────────────────────────────
//
// Contract rules that the whole team depends on:
//   • `code`     — stable, UPPERCASE, `CAT-NNN` style, never reused. The AI's
//                  only legal output for the type field is one of these codes.
//   • `wire`     — snake_case, used verbatim in JSON and the WSS payloads.
//                  Never rename a `wire` value after the backend is seeded.
//   • `labelRo`  — human label shown in the UI; may be reworded freely.
//   • `urgency`  — may be RAISED by the AI for a specific report, never
//                  lowered below this default (server-enforced).
// =============================================================================

import 'dart:convert';

/// Functional bucket of an incident. Exactly four, matching the taxonomy doc.
enum IncidentCategory {
  safetyFire('safety_fire', 'Siguranță și incendiu'),
  security('security', 'Securitate'),
  maintenance('maintenance', 'Mentenanță'),
  operations('operations', 'Operațiuni');

  const IncidentCategory(this.wire, this.labelRo);

  /// snake_case value used verbatim in JSON / WSS payloads.
  final String wire;

  /// Romanian label for the UI.
  final String labelRo;

  static IncidentCategory fromWire(String value) {
    final parsed = tryFromWire(value);
    if (parsed == null) {
      throw FormatException(
        'Unknown IncidentCategory "${value}". '
        'Expected one of: ${IncidentCategory.values.map((c) => c.wire).join(", ")}',
      );
    }
    return parsed;
  }

  static IncidentCategory? tryFromWire(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final category in IncidentCategory.values) {
      if (category.wire == normalized) return category;
    }
    return null;
  }
}

/// Priority of a ticket. `level` is used for sorting the dispatcher dashboard
/// (higher = more urgent).
enum Urgency {
  low('low', 'Scăzută', 1),
  medium('medium', 'Medie', 2),
  high('high', 'Ridicată', 3),
  critical('critical', 'Critică', 4);

  const Urgency(this.wire, this.labelRo, this.level);

  final String wire;
  final String labelRo;
  final int level;

  static Urgency fromWire(String value) {
    final parsed = tryFromWire(value);
    if (parsed == null) {
      throw FormatException(
        'Unknown Urgency "${value}". '
        'Expected one of: ${Urgency.values.map((u) => u.wire).join(", ")}',
      );
    }
    return parsed;
  }

  static Urgency? tryFromWire(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final urgency in Urgency.values) {
      if (urgency.wire == normalized) return urgency;
    }
    return null;
  }

  /// Returns the more urgent of two values (server uses this to allow the AI
  /// to escalate but never de-escalate).
  static Urgency max(Urgency a, Urgency b) => a.level >= b.level ? a : b;
}

/// Closed list of responder departments. The dispatcher dashboard groups
/// tickets by these; crews filter by these.
enum Department {
  security('security', 'Securitate'),
  fireRescue('fire_rescue', 'Pompieri / Salvare'),
  medical('medical', 'Medical'),
  maintenance('maintenance', 'Mentenanță'),
  operations('operations', 'Operațiuni'),
  terminal('terminal', 'Servicii Terminal'),
  it('it', 'IT / Comunicații'),
  baggage('baggage', 'Bagaje'),
  airside('airside', 'Platformă / Airside');

  const Department(this.wire, this.labelRo);

  final String wire;
  final String labelRo;

  static Department fromWire(String value) {
    final parsed = tryFromWire(value);
    if (parsed == null) {
      throw FormatException(
        'Unknown Department "${value}". '
        'Expected one of: ${Department.values.map((d) => d.wire).join(", ")}',
      );
    }
    return parsed;
  }

  static Department? tryFromWire(String? value) {
    if (value == null) return null;
    final normalized = value.trim().toLowerCase();
    for (final department in Department.values) {
      if (department.wire == normalized) return department;
    }
    return null;
  }
}

/// One entry of the closed taxonomy: what the AI may pick, what the UI shows,
/// which departments get notified by default.
class IncidentType {
  const IncidentType({
    required this.code,
    required this.labelRo,
    required this.category,
    required this.urgency,
    required this.primaryDepartments,
    this.standbyDepartments = const <Department>[],
  });

  /// Stable identifier, e.g. `SF-FIRE`. This is the ONLY thing the AI returns
  /// and the only thing persisted on a ticket. Never change once shipped.
  final String code;

  /// Romanian display label.
  final String labelRo;

  final IncidentCategory category;

  /// Default urgency (the AI may escalate per-report, never de-escalate).
  final Urgency urgency;

  /// Departments that get the dispatch by default.
  final List<Department> primaryDepartments;

  /// Departments notified for awareness / escalation.
  final List<Department> standbyDepartments;

  /// Primary + standby, deduplicated, primary first.
  List<Department> get allDepartments {
    final seen = <Department>{};
    final result = <Department>[];
    for (final department in [...primaryDepartments, ...standbyDepartments]) {
      if (seen.add(department)) result.add(department);
    }
    return List<Department>.unmodifiable(result);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'code': code,
        'label_ro': labelRo,
        'category': category.wire,
        'urgency': urgency.wire,
        'primary_departments':
            primaryDepartments.map((d) => d.wire).toList(growable: false),
        'standby_departments':
            standbyDepartments.map((d) => d.wire).toList(growable: false),
      };

  factory IncidentType.fromJson(Map<String, dynamic> json) {
    final code = json['code'];
    final labelRo = json['label_ro'];
    if (code is! String || code.trim().isEmpty) {
      throw const FormatException('IncidentType: missing "code"');
    }
    if (labelRo is! String) {
      throw FormatException('IncidentType($code): missing "label_ro"');
    }
    return IncidentType(
      code: code,
      labelRo: labelRo,
      category: IncidentCategory.fromWire(json['category'] as String? ?? ''),
      urgency: Urgency.fromWire(json['urgency'] as String? ?? ''),
      primaryDepartments: _parseDepartments(json['primary_departments']),
      standbyDepartments: _parseDepartments(json['standby_departments']),
    );
  }

  static List<Department> _parseDepartments(Object? value) {
    if (value == null) return const <Department>[];
    if (value is! List) {
      throw FormatException('IncidentType departments: expected a list, got '
          '${value.runtimeType}');
    }
    final departments = <Department>[];
    for (final item in value) {
      if (item is String) departments.add(Department.fromWire(item));
    }
    return List<Department>.unmodifiable(departments);
  }

  @override
  String toString() => '$code ($labelRo)';
}

/// The closed registry. Everything (AI prompt, dispatcher filter chips, crew
/// routing, backend validation) is derived from [all].
class IncidentTaxonomy {
  const IncidentTaxonomy._();

  /// Bump when the WIRE format changes (not when labels change).
  static const int schemaVersion = 1;

  /// Hard requirement from the product spec: exactly 14 types, 4 categories.
  static const int expectedCount = 14;

  // ───────────────────────────────────────────────────────────────────────────
  // THE 14 TYPES — replace this block with the taxonomy doc, nothing else.
  // NOTE: codes/codes below are the team's working set; `OP-OTHER` is the
  // mandatory catch-all so a garbage/unknown report can always be routed to
  // the dispatcher instead of crashing the flow.
  // ───────────────────────────────────────────────────────────────────────────
  static const List<IncidentType> all = <IncidentType>[
    // ── SIGURANȚĂ ȘI INCENDIU ────────────────────────────────────────────────
    IncidentType(
      code: 'SF-FIRE',
      labelRo: 'Foc sau fum în terminal',
      category: IncidentCategory.safetyFire,
      urgency: Urgency.critical,
      primaryDepartments: <Department>[
        Department.fireRescue,
        Department.security,
      ],
      standbyDepartments: <Department>[
        Department.operations,
        Department.maintenance,
      ],
    ),
    IncidentType(
      code: 'SF-FOD',
      labelRo: 'Corp străin pe platformă sau cale de rulare',
      category: IncidentCategory.safetyFire,
      urgency: Urgency.critical,
      primaryDepartments: <Department>[
        Department.airside,
        Department.operations,
      ],
      standbyDepartments: <Department>[
        Department.maintenance,
        Department.security,
      ],
    ),
    IncidentType(
      code: 'SF-SPILL',
      labelRo: 'Scurgere de lichid cu pericol de alunecare',
      category: IncidentCategory.safetyFire,
      urgency: Urgency.medium,
      primaryDepartments: <Department>[
        Department.maintenance,
        Department.terminal,
      ],
      standbyDepartments: <Department>[Department.operations],
    ),
    IncidentType(
      code: 'SF-EQUIP',
      labelRo: 'Echipament de stingere defect sau lipsă',
      category: IncidentCategory.safetyFire,
      urgency: Urgency.high,
      primaryDepartments: <Department>[
        Department.fireRescue,
        Department.maintenance,
      ],
      standbyDepartments: <Department>[Department.operations],
    ),

    // ── SECURITATE ───────────────────────────────────────────────────────────
    IncidentType(
      code: 'SC-BAG',
      labelRo: 'Bagaj nesupravegheat sau abandonat',
      category: IncidentCategory.security,
      urgency: Urgency.high,
      primaryDepartments: <Department>[Department.security],
      standbyDepartments: <Department>[
        Department.operations,
        Department.terminal,
      ],
    ),
    IncidentType(
      code: 'SC-ACCESS',
      labelRo: 'Acces neautorizat în zonă restricționată',
      category: IncidentCategory.security,
      urgency: Urgency.critical,
      primaryDepartments: <Department>[
        Department.security,
        Department.airside,
      ],
      standbyDepartments: <Department>[Department.operations],
    ),
    IncidentType(
      code: 'SC-ITEM',
      labelRo: 'Obiect interzis identificat la control',
      category: IncidentCategory.security,
      urgency: Urgency.high,
      primaryDepartments: <Department>[Department.security],
      standbyDepartments: <Department>[Department.operations],
    ),
    IncidentType(
      code: 'SC-BEHAV',
      labelRo: 'Comportament suspect sau altercație',
      category: IncidentCategory.security,
      urgency: Urgency.high,
      primaryDepartments: <Department>[Department.security],
      standbyDepartments: <Department>[
        Department.medical,
        Department.operations,
      ],
    ),

    // ── MENTENANȚĂ ───────────────────────────────────────────────────────────
    IncidentType(
      code: 'MT-BELT',
      labelRo: 'Defecțiune bandă transportoare bagaje',
      category: IncidentCategory.maintenance,
      urgency: Urgency.high,
      primaryDepartments: <Department>[
        Department.baggage,
        Department.maintenance,
      ],
      standbyDepartments: <Department>[Department.operations],
    ),
    IncidentType(
      code: 'MT-ESC',
      labelRo: 'Defecțiune escalator sau lift',
      category: IncidentCategory.maintenance,
      urgency: Urgency.medium,
      primaryDepartments: <Department>[
        Department.maintenance,
        Department.terminal,
      ],
      standbyDepartments: <Department>[Department.operations],
    ),
    IncidentType(
      code: 'MT-JBRIDGE',
      labelRo: 'Defecțiune pasarelă de îmbarcare',
      category: IncidentCategory.maintenance,
      urgency: Urgency.high,
      primaryDepartments: <Department>[
        Department.maintenance,
        Department.operations,
      ],
      standbyDepartments: <Department>[Department.airside],
    ),

    // ── OPERAȚIUNI ───────────────────────────────────────────────────────────
    IncidentType(
      code: 'OP-QUEUE',
      labelRo: 'Aglomerare la controlul de securitate',
      category: IncidentCategory.operations,
      urgency: Urgency.medium,
      primaryDepartments: <Department>[
        Department.security,
        Department.operations,
      ],
      standbyDepartments: <Department>[Department.terminal],
    ),
    IncidentType(
      code: 'OP-IT',
      labelRo: 'Cădere sistem IT pentru check-in',
      category: IncidentCategory.operations,
      urgency: Urgency.high,
      primaryDepartments: <Department>[
        Department.it,
        Department.operations,
      ],
      standbyDepartments: <Department>[Department.maintenance],
    ),
    IncidentType(
      code: 'OP-OTHER',
      labelRo: 'Alt incident nespecificat (triaj dispecer)',
      category: IncidentCategory.operations,
      urgency: Urgency.low,
      primaryDepartments: <Department>[Department.operations],
      standbyDepartments: <Department>[
        Department.security,
        Department.maintenance,
      ],
    ),
  ];

  static final Map<String, IncidentType> _byCode = <String, IncidentType>{
    for (final type in all) type.code: type,
  };

  /// All 14 codes, in taxonomy order.
  static List<String> get codes =>
      List<String>.unmodifiable(all.map((type) => type.code));

  /// Lookup used by the app when a ticket arrives from the server.
  static IncidentType? byCode(String code) => _byCode[code.trim().toUpperCase()];

  /// Throwing lookup — use in UI flows where an unknown code is a real bug.
  static IncidentType requireCode(String code) {
    final type = byCode(code);
    if (type == null) {
      throw FormatException(
        'Incident code "$code" is not in the closed taxonomy. '
        'Known codes: ${codes.join(", ")}',
      );
    }
    return type;
  }

  static bool isValidCode(String code) => byCode(code) != null;

  static List<IncidentType> byCategory(IncidentCategory category) =>
      List<IncidentType>.unmodifiable(
        all.where((type) => type.category == category),
      );

  /// Compact catalog injected into the Ollama system prompt (the backend uses
  /// `backend/taxonomy.json`, generated from this file; this getter exists so
  /// the catalog can also be rendered in-app, e.g. for the manual menu).
  static List<String> get promptCatalogLines => List<String>.unmodifiable(
        all.map(
          (type) => '${type.code} | ${type.category.wire} | '
              'urgency=${type.urgency.wire} | ${type.labelRo} | '
              'departments=${type.primaryDepartments.map((d) => d.wire).join(",")}',
        ),
      );

  /// Full JSON catalog (same shape as `backend/taxonomy.json`).
  static Map<String, dynamic> toJson() => <String, dynamic>{
        'version': schemaVersion,
        'generated_from': 'lib/core/incidents/taxonomy.dart',
        'categories': <Map<String, String>>[
          for (final category in IncidentCategory.values)
            <String, String>{
              'wire': category.wire,
              'label_ro': category.labelRo,
            },
        ],
        'types': <Map<String, dynamic>>[
          for (final type in all) type.toJson(),
        ],
      };

  /// Pretty JSON, used by `tool/emit_taxonomy.dart` to regenerate
  /// `backend/taxonomy.json`.
  static String toJsonString() =>
      const JsonEncoder.withIndent('  ').convert(toJson());

  /// Fail-fast integrity check. Calls `assert(IncidentTaxonomy.validate)` in
  /// `main.dart` debug builds; also exercised by `tool/emit_taxonomy.dart`.
  /// Throws [StateError] listing every problem found.
  static void validate() {
    final problems = <String>[];

    if (all.length != expectedCount) {
      problems.add('expected $expectedCount incident types, found ${all.length}');
    }

    final seen = <String>{};
    for (final type in all) {
      final code = type.code.trim();
      if (code.isEmpty) {
        problems.add('an incident type has an empty code');
        continue;
      }
      if (code != code.toUpperCase()) {
        problems.add('$code: code must be UPPERCASE');
      }
      if (!seen.add(code)) {
        problems.add('$code: duplicate code');
      }
      if (type.labelRo.trim().isEmpty) {
        problems.add('$code: empty labelRo');
      }
      if (type.primaryDepartments.isEmpty) {
        problems.add('$code: at least one primary department is required');
      }
      final duplicates = <Department>{};
      for (final department in type.primaryDepartments) {
        if (!duplicates.add(department)) {
          problems.add('$code: duplicate primary department ${department.wire}');
        }
      }
    }

    for (final category in IncidentCategory.values) {
      if (byCategory(category).isEmpty) {
        problems.add('category "${category.wire}" has no incident types');
      }
    }

    if (problems.isNotEmpty) {
      throw StateError('Invalid incident taxonomy:\n - ${problems.join('\n - ')}');
    }
  }
}
