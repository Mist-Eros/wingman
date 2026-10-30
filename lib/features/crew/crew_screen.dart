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
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: const Color(0xFFF4F7FB),
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Echipaj',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: Color(0xFF0F172A),
              ),
            ),
            Text(
              session.displayName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          _AppBarIconButton(
            tooltip: 'Reîmprospătează',
            icon: Icons.refresh_rounded,
            onPressed: board.refresh,
          ),
          const SizedBox(width: 4),
          _AppBarIconButton(
            tooltip: 'Ieși din rol',
            icon: Icons.logout_rounded,
            onPressed: () => CoreScope.of(context).onSignOut(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Color(0xFFF4F7FB),
              Color(0xFFE8EEF5),
              Color(0xFFE2EAF3),
            ],
          ),
        ),
        child: ListenableBuilder(
          listenable: board,
          builder: (BuildContext context, Widget? _) {
            final queue = _crewQueue(board.tickets);

            return Column(
              children: <Widget>[
                WssBanner(connected: board.connected),
                if (board.lastError != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Material(
                      color: const Color(0xFFFCE8E6),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Icons.error_outline_rounded,
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
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: queue.isEmpty
                      ? _EmptyState(loading: board.loading)
                      : RefreshIndicator(
                          color: const Color(0xFF0F766E),
                          onRefresh: board.refresh,
                          child: ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                            itemCount: queue.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (BuildContext context, int index) {
                              final ticket = queue[index];
                              return TweenAnimationBuilder<double>(
                                tween: Tween<double>(begin: 0, end: 1),
                                duration: Duration(
                                  milliseconds: 280 + (index * 40).clamp(0, 160),
                                ),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Opacity(
                                    opacity: value,
                                    child: Transform.translate(
                                      offset: Offset(0, 10 * (1 - value)),
                                      child: child,
                                    ),
                                  );
                                },
                                child: CrewTicketCard(
                                  key: ValueKey<String>(ticket.id),
                                  ticket: ticket,
                                  crewId: session.userId,
                                  onJoin: () => board.join(
                                    ticket.id,
                                    crewId: session.userId,
                                    crewName: session.displayName,
                                  ),
                                  onVote: () => board.vote(
                                    ticket.id,
                                    crewId: session.userId,
                                  ),
                                  lastActionError: () => board.lastActionError,
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AppBarIconButton extends StatelessWidget {
  const _AppBarIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(
          side: BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: const Color(0xFF334155)),
          ),
        ),
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
        padding: const EdgeInsets.all(36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (loading)
              const Padding(
                padding: EdgeInsets.only(bottom: 18),
                child: CircularProgressIndicator(
                  color: Color(0xFF0F766E),
                  strokeWidth: 2.5,
                ),
              )
            else
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 20,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.engineering_outlined,
                  size: 40,
                  color: Color(0xFF0F766E),
                ),
              ),
            const SizedBox(height: 18),
            Text(
              loading
                  ? 'Se încarcă intervențiile…'
                  : 'Nicio intervenție alocată',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0F172A),
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
                color: const Color(0xFF64748B),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
