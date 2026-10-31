import 'package:flutter/material.dart';

import '../../core/accessibility/accessibility_screen.dart';
import '../../core/core_scope.dart';
import '../../core/models/ticket.dart';
import '../../core/theme/wingman_theme.dart';
import '../../core/rewards/reward_policy.dart';

/// Employee account: points + attended tickets. This screen is intentionally
/// reward-policy agnostic — it renders whatever ledger [CoreScope] provides.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final board = CoreScope.boardOf(context);
    final session = CoreScope.sessionOf(context);
    final domain = CoreScope.domainOf(context);
    final rewards = CoreScope.rewardsOf(context);
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: board,
      builder: (context, _) {
        final ledger = rewards.ledgerFor(
          crewId: session.userId,
          tickets: board.tickets,
        );

        return Scaffold(
          appBar: AppBar(
            title: const Text('Contul meu'),
            actions: <Widget>[
              if (domain.features.accessibility)
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
              _PointsHeader(
                name: session.displayName,
                roleLine: '${session.role.labelRo} · ${session.scopeLabel}',
                points: ledger.totalPoints,
                label: rewards.pointsLabel,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: _Stat(
                      value: '${ledger.reportedCount}',
                      label: 'raportate',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      value: '${ledger.attendedCount}',
                      label: 'intervenții',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      value: '${ledger.resolvedCount}',
                      label: 'rezolvate',
                    ),
                  ),
                ],
              ),
              if (ledger.blockedSelfResolutions > 0) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '${ledger.blockedSelfResolutions} raportări auto-rezolvate '
                  'nu au primit puncte (incident nepericulos).',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: WingmanColors.pending,
                  ),
                ),
              ],
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
                'Punctele se resetează la resetarea datelor.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              if (ledger.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.history_toggle_off,
                        size: 46,
                        color: WingmanColors.muted,
                      ),
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
                for (final entry in ledger.entries)
                  _AccountTicketCard(
                    entry: entry,
                    pointsLabel: rewards.pointsLabel.toLowerCase(),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _PointsHeader extends StatelessWidget {
  const _PointsHeader({
    required this.name,
    required this.roleLine,
    required this.points,
    required this.label,
  });

  final String name;
  final String roleLine;
  final int points;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  roleLine,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
              Text(
                label,
                style: const TextStyle(
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
  const _AccountTicketCard({
    required this.entry,
    required this.pointsLabel,
  });

  final RewardEntry entry;
  final String pointsLabel;

  @override
  Widget build(BuildContext context) {
    final ticket = entry.ticket;
    final resolved = ticket.status == TicketStatus.resolved;
    final denied = ticket.status == TicketStatus.denied;
    final color = resolved
        ? WingmanColors.resolved
        : denied
            ? WingmanColors.denied
            : WingmanColors.inProgress;
    final local = ticket.updatedAt.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');

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
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 4,
                ),
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
                '+${entry.points} $pointsLabel',
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
            '${two(local.day)}.${two(local.month)} '
            '${two(local.hour)}:${two(local.minute)}',
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
