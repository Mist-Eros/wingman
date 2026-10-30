// =============================================================================
// STUB — OWNER: Friend 1 (lib/features/reporter/).
//
// Replace this whole file. FROZEN CONTRACT (main.dart depends on it):
//   • class name: ReporterScreen
//   • const constructor, no required arguments
//   • obtain deps with CoreScope, never constructor-inject:
//       final session = CoreScope.sessionOf(context);
//       final api     = CoreScope.apiOf(context);
//       final board   = CoreScope.boardOf(context);
//
// Suggested flow: big "Raportează" button → (voice) record + STT → POST
// /api/reports via `api.report(ReportDraft(...))`; or the 14-type button menu
// with `hintCode` set. Show `IncidentTaxonomy.all` grouped by category.
// `api.report` can take ~20-30 s on a cold model: disable the button and show
// a spinner + "AI analizează..." text.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/incidents/taxonomy.dart';

class ReporterScreen extends StatelessWidget {
  const ReporterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raportare incident'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Ieși din rol',
            icon: const Icon(Icons.logout),
            onPressed: () => CoreScope.of(context).onSignOut(),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: board,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(
              'STUB reporter — ${session.displayName}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Aici vine fluxul conversațional (voce + meniu). '
              'Contractul: ReporterScreen(), CoreScope, '
              'api.report(ReportDraft(...)).',
            ),
            const SizedBox(height: 16),
            Text('Meniu (${IncidentTaxonomy.all.length} tipuri):'),
            const SizedBox(height: 8),
            for (final type in IncidentTaxonomy.all)
              ListTile(
                dense: true,
                title: Text(type.labelRo),
                subtitle: Text(
                  '${type.code} · ${type.urgency.labelRo} · '
                  '${type.primaryDepartments.map((d) => d.labelRo).join(", ")}',
                ),
              ),
            const SizedBox(height: 16),
            Text('Tichete pe server: ${board.tickets.length}'),
          ],
        ),
      ),
    );
  }
}
