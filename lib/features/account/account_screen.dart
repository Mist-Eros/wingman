import 'package:flutter/material.dart';

import '../../core/accessibility/accessibility_screen.dart';
import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';
import '../../core/theme/wingman_theme.dart';

/// Employee account tab: points + the incidents this person attended.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: board,
      builder: (context, _) {
        final attended = board.tickets
            .where((ticket) => ticket.joinedCrewIds.contains(session.userId))
            .toList()
          ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

        var points = 0;
        for (final ticket in attended) {
          points += 2; // joined / attended
          if (ticket.status == TicketStatus.resolved) points += 10;
        }
        final resolved = attended
            .where((ticket) => ticket.status == TicketStatus.resolved)
            .length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Contul meu'),
            actions: <Widget>[
              IconButton(
                tooltip: 'Accesibilitate',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccessibilityScreen(),
                  ),
                ),
                icon: const Icon(Icons.accessibility_new_rounded),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: WingmanColors.navy,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withValues(alpha: 0.16),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            session.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${session.role.labelRo} · ${session.scopeLabel}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          '$points',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                        const Text(
                          'PUNCTE',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      value: '${attended.length}',
                      label: 'intervenții',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(value: '$resolved', label: 'rezolvate'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                        value: '${attended.length - resolved}',
                        label: 'în curs'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Istoricul meu',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tichetele la care ai participat (Preia / Rezolvat). '
                'Punctele se resetează la resetarea demo-ului.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (attended.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: <Widget>[
                      Icon(Icons.history_toggle_off,
                          size: 46, color: WingmanColors.muted),
                      SizedBox(height: 8),
                      Text(
                        'Nicio intervenție încă.\n'
                        'Preia un tichet din coada echipajului.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: WingmanColors.muted),
                      ),
                    ],
                  ),
                )
              else
                for (final ticket in attended)
                  _AccountTicketCard(ticket: ticket),
            ],
          ),
        );
      },
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: WingmanColors.line),
      ),
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: WingmanColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTicketCard extends StatelessWidget {
  const _AccountTicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final resolved = ticket.status == TicketStatus.resolved;
    final denied = ticket.status == TicketStatus.denied;
    final color = resolved
        ? WingmanColors.resolved
        : denied
            ? WingmanColors.denied
            : WingmanColors.inProgress;
    final points = 2 + (resolved ? 10 : 0);
    final local = ticket.updatedAt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: WingmanColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ticket.status.labelRo,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                '+$points puncte',
                style: const TextStyle(
                  color: WingmanColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.labelRo,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '${ticket.incidentCode} · ${ticket.location.display} · '
            '${two(local.day)}.${two(local.month)} ${two(local.hour)}:${two(local.minute)}',
            style: const TextStyle(
              color: WingmanColors.muted,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
