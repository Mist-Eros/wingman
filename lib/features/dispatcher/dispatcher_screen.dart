// =============================================================================
// STUB — OWNER: Friend 2 (lib/features/dispatcher/).
//
// Replace this whole file. FROZEN CONTRACT (main.dart depends on it):
//   • class name: DispatcherScreen
//   • const constructor, no required arguments
//   • obtain deps with CoreScope:
//       final session = CoreScope.sessionOf(context);
//       final board   = CoreScope.boardOf(context);   // live tickets
//
// Suggested flow: `board.pendingOverrides` at the top with a 5-second
// countdown (`ticket.remainingOverrideSeconds()` + a 250ms Ticker/Timer),
// buttons Confirm / Deny / Reclassify (call `board.confirm(ticket.id)`,
// `board.deny(...)`, `board.reclassify(...)` — each returns bool and sets
// `board.lastActionError` on failure). Then the active list with
// urgency/confidence chips and department filters
// (`board.forDepartment(Department.security)`).
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';

class DispatcherScreen extends StatelessWidget {
  const DispatcherScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispecerat'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reîmprospătează',
            icon: const Icon(Icons.refresh),
            onPressed: board.refresh,
          ),
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
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text('STUB dispatcher — ${session.displayName}'),
            Text(
              board.connected ? 'WSS: conectat' : 'WSS: deconectat',
              style: TextStyle(
                color: board.connected ? Colors.green : Colors.red,
              ),
            ),
            if (board.lastError != null)
              Text(
                board.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const Divider(height: 24),
            if (board.tickets.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Niciun tichet încă. Raportează din app-ul reporter.'),
              ),
            for (final Ticket ticket in board.tickets)
              Card(
                child: ListTile(
                  title: Text('${ticket.incidentCode} · ${ticket.labelRo}'),
                  subtitle: Text(
                    '${ticket.status.labelRo} · ${ticket.urgency.labelRo} · '
                    '${ticket.confidenceLabel} · ${ticket.location.display}',
                  ),
                  trailing: Text(
                    '${ticket.resolveVotes}/${ticket.quorum}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
