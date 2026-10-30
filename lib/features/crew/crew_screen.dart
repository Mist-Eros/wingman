// =============================================================================
// STUB — OWNER: Friend 3 (lib/features/crew/).
//
// Replace this whole file. FROZEN CONTRACT (main.dart depends on it):
//   • class name: CrewScreen
//   • const constructor, no required arguments
//   • obtain deps with CoreScope:
//       final session = CoreScope.sessionOf(context);
//       final board   = CoreScope.boardOf(context);
//
// Suggested flow: list `board.tickets.where((t) => t.status == dispatched ||
// t.status == inProgress)`; "Preia" → `board.join(t.id, crewId:
// session.userId, crewName: session.displayName)`; then "Rezolvat" vote →
// `board.vote(t.id, crewId: session.userId)`. Disable buttons when
// `t.isJoinedBy(session.userId)` / `t.hasVotedBy(session.userId)`; show
// `${t.resolveVotes}/${t.quorum}` and a SnackBar when it flips to resolved.
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';

class CrewScreen extends StatelessWidget {
  const CrewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);
    final queue = board.tickets
        .where((Ticket ticket) =>
            ticket.status == TicketStatus.dispatched ||
            ticket.status == TicketStatus.inProgress)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Echipaj'),
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
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            Text('STUB crew — ${session.displayName}'),
            Text(board.connected ? 'WSS: conectat' : 'WSS: deconectat'),
            const Divider(height: 24),
            if (queue.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('Nicio intervenție alocată momentan.'),
              ),
            for (final ticket in queue)
              Card(
                child: ListTile(
                  title: Text('${ticket.incidentCode} · ${ticket.labelRo}'),
                  subtitle: Text(
                    '${ticket.urgency.labelRo} · ${ticket.location.display} · '
                    'locuri: ${ticket.joinedCrewIds.length}',
                  ),
                  trailing: Text('${ticket.resolveVotes}/${ticket.quorum}'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
