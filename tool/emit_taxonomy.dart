// =============================================================================
// tool/emit_taxonomy.dart
//
// Generates `backend/taxonomy.json` FROM `lib/core/incidents/taxonomy.dart`, so
// the Flutter app and the FastAPI/Ollama side can never drift.
//
// Run from the repo root (Dart SDK ships with Flutter):
//   dart run tool/emit_taxonomy.dart --write     # regenerate JSON
//   dart run tool/emit_taxonomy.dart            # print JSON to stdout
//
// The Python equivalent (works without a Dart SDK, parses this same Dart file)
// is `python scripts/sync_taxonomy.py --write`.
// =============================================================================

import 'dart:io';

import '../lib/core/incidents/taxonomy.dart';

void main(List<String> args) {
  // Throws StateError with a per-problem list if the taxonomy is invalid
  // (wrong count, duplicate code, empty departments, empty category...).
  IncidentTaxonomy.validate();

  final json = IncidentTaxonomy.toJsonString();
  final shouldWrite = args.contains('--write') || args.contains('-w');

  if (shouldWrite) {
    final file = File('backend/taxonomy.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$json\n');
    stderr.writeln('Wrote ${file.path}');
  } else {
    stdout.writeln(json);
  }

  final byCategory = <String, int>{};
  for (final type in IncidentTaxonomy.all) {
    byCategory.update(type.category.wire, (count) => count + 1,
        ifAbsent: () => 1);
  }
  stderr
    ..writeln('OK · ${IncidentTaxonomy.all.length} incident types · '
        'schema v${IncidentTaxonomy.schemaVersion}')
    ..writeln('Categories: ${byCategory.entries.map((e) => '${e.key}=${e.value}').join(', ')}');
}
