// =============================================================================
// OWNER: Friend 3 (lib/features/crew/).
//
// FROZEN CONTRACT (main.dart depends on it):
//   • class name: CrewScreen
//   • const constructor, no required arguments
//   • obtain deps with CoreScope only
// =============================================================================

import 'package:flutter/material.dart';

import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';
import 'crew_ticket_card.dart';
import 'wss_banner.dart';

class CrewScreen extends StatefulWidget {
  const CrewScreen({super.key});

  @override
  State<CrewScreen> createState() => _CrewScreenState();
}

class _CrewScreenState extends State<CrewScreen> {
  /// Tracks last-known status so we can SnackBar when a ticket flips to resolved
  /// via WSS (own vote or another crew member).
  final Map<String, TicketStatus> _seenStatus = <String, TicketStatus>{};
  TicketBoard? _board;

  List<Ticket> _crewQueue(Iterable<Ticket> tickets) => tickets
      .where(
        (Ticket ticket) =>
            ticket.status == TicketStatus.dispatched ||
            ticket.status == TicketStatus.inProgress,
      )
      .toList(growable: false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final board = CoreScope.boardOf(context);
    if (!identical(_board, board)) {
      _board?.removeListener(_onBoardChanged);
      _board = board;
      _board!.addListener(_onBoardChanged);
      _seedStatuses(board.tickets);
    }
  }

  @override
  void dispose() {
    _board?.removeListener(_onBoardChanged);
    super.dispose();
  }

  void _seedStatuses(List<Ticket> tickets) {
    for (final ticket in tickets) {
      _seenStatus.putIfAbsent(ticket.id, () => ticket.status);
    }
  }

  void _onBoardChanged() {
    final board = _board;
    if (board == null || !mounted) return;

    final newlyResolved = <Ticket>[];
    for (final ticket in board.tickets) {
      final previous = _seenStatus[ticket.id];
      _seenStatus[ticket.id] = ticket.status;
      if (previous != null &&
          previous != TicketStatus.resolved &&
          ticket.status == TicketStatus.resolved) {
        newlyResolved.add(ticket);
      }
    }

    for (final ticket in newlyResolved) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Intervenție rezolvată · ${ticket.incidentCode}'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Echipaj'),
            Text(
              session.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
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
        builder: (BuildContext context, Widget? _) {
          final queue = _crewQueue(board.tickets);

          return Column(
            children: <Widget>[
              WssBanner(connected: board.connected),
              if (board.lastError != null)
                Material(
                  color: const Color(0xFFFCE8E6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: Color(0xFFB3261E),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            board.lastError!,
                            style: const TextStyle(
                              color: Color(0xFFB3261E),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: queue.isEmpty
                    ? _EmptyState(loading: board.loading)
                    : RefreshIndicator(
                        onRefresh: board.refresh,
                        child: ListView.separated(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                          itemCount: queue.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (BuildContext context, int index) {
                            final ticket = queue[index];
                            return CrewTicketCard(
                              key: ValueKey<String>(ticket.id),
                              ticket: ticket,
                              crewId: session.userId,
                              crewName: session.displayName,
                              board: board,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.loading});

  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              )
            else
              Icon(
                Icons.engineering_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            const SizedBox(height: 12),
            Text(
              loading
                  ? 'Se încarcă intervențiile…'
                  : 'Nicio intervenție alocată',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              loading
                  ? 'Așteaptă sincronizarea cu serverul.'
                  : 'Când dispeceratul trimite un tichet, apare aici. '
                      'Trage în jos pentru reîmprospătare.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
