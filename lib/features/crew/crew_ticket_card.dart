import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';

/// One dispatched / in-progress ticket with Preia + Rezolvat actions.
class CrewTicketCard extends StatefulWidget {
  const CrewTicketCard({
    super.key,
    required this.ticket,
    required this.crewId,
    required this.crewName,
    required this.board,
  });

  final Ticket ticket;
  final String crewId;
  final String crewName;
  final TicketBoard board;

  @override
  State<CrewTicketCard> createState() => _CrewTicketCardState();
}

class _CrewTicketCardState extends State<CrewTicketCard> {
  bool _joining = false;
  bool _voting = false;
  bool _expanded = false;

  Ticket get _ticket => widget.ticket;
  bool get _joined => _ticket.isJoinedBy(widget.crewId);
  bool get _voted => _ticket.hasVotedBy(widget.crewId);
  bool get _busy => _joining || _voting;

  Color get _accent {
    switch (_ticket.category) {
      case IncidentCategory.safetyFire:
        return const Color(0xFFC62828);
      case IncidentCategory.security:
        return const Color(0xFF1565C0);
      case IncidentCategory.maintenance:
        return const Color(0xFFEF6C00);
      case IncidentCategory.operations:
        return const Color(0xFF00897B);
    }
  }

  Color get _urgencyColor {
    switch (_ticket.urgency) {
      case Urgency.critical:
        return const Color(0xFFB71C1C);
      case Urgency.high:
        return const Color(0xFFE65100);
      case Urgency.medium:
        return const Color(0xFFF9A825);
      case Urgency.low:
        return const Color(0xFF558B2F);
    }
  }

  Future<void> _onJoin() async {
    if (_joined || _busy) return;
    setState(() => _joining = true);
    final ok = await widget.board.join(
      _ticket.id,
      crewId: widget.crewId,
      crewName: widget.crewName,
    );
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (ok) _expanded = true;
    });
    if (!ok) {
      _showError(widget.board.lastActionError ?? 'Nu am putut prelua intervenția.');
    }
  }

  Future<void> _onVote() async {
    if (!_joined || _voted || _busy) return;
    setState(() => _voting = true);
    final ok = await widget.board.vote(
      _ticket.id,
      crewId: widget.crewId,
    );
    if (!mounted) return;
    setState(() => _voting = false);
    if (!ok) {
      _showError(widget.board.lastActionError ?? 'Votul nu a putut fi înregistrat.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB3261E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinedCount = _ticket.joinedCrewIds.length;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1.5,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(color: _accent, width: 4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _ticket.incidentCode,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _ticket.labelRo,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: <Widget>[
                    _Chip(
                      label: _ticket.urgency.labelRo,
                      color: _urgencyColor,
                      filled: true,
                    ),
                    _Chip(
                      label: _ticket.status.labelRo,
                      color: _accent,
                    ),
                    _Chip(
                      label: _ticket.departmentsLabel,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MetaRow(
                  icon: Icons.place_outlined,
                  text: _ticket.location.display,
                ),
                const SizedBox(height: 4),
                _MetaRow(
                  icon: Icons.groups_outlined,
                  text: joinedCount == 0
                      ? 'Nimeni nu a preluat încă'
                      : '$joinedCount '
                          '${joinedCount == 1 ? 'membru' : 'membri'} alăturați',
                ),
                const SizedBox(height: 4),
                _MetaRow(
                  icon: Icons.how_to_vote_outlined,
                  text: 'Voturi: ${_ticket.resolveVotes}/${_ticket.quorum}',
                ),
                if (_expanded) ...<Widget>[
                  const SizedBox(height: 14),
                  _DispatchPanel(
                    joined: _joined,
                    voted: _voted,
                    joining: _joining,
                    voting: _voting,
                    joinedCount: joinedCount,
                    joinedIds: _ticket.joinedCrewIds,
                    resolveVotes: _ticket.resolveVotes,
                    quorum: _ticket.quorum,
                    onJoin: _onJoin,
                    onVote: _onVote,
                    accent: _accent,
                  ),
                ] else if (!_joined) ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : () {
                        setState(() => _expanded = true);
                        _onJoin();
                      },
                      icon: _joining
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.handshake_outlined),
                      label: Text(_joining ? 'Se preia…' : 'Preia'),
                      style: FilledButton.styleFrom(
                        backgroundColor: _accent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ] else ...<Widget>[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: (_voted || _busy) ? null : _onVote,
                      icon: _voting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _voted
                                  ? Icons.check_circle_outline
                                  : Icons.task_alt,
                            ),
                      label: Text(
                        _voted
                            ? 'Ai votat (${_ticket.resolveVotes}/${_ticket.quorum})'
                            : 'Rezolvat',
                      ),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DispatchPanel extends StatelessWidget {
  const _DispatchPanel({
    required this.joined,
    required this.voted,
    required this.joining,
    required this.voting,
    required this.joinedCount,
    required this.joinedIds,
    required this.resolveVotes,
    required this.quorum,
    required this.onJoin,
    required this.onVote,
    required this.accent,
  });

  final bool joined;
  final bool voted;
  final bool joining;
  final bool voting;
  final int joinedCount;
  final List<String> joinedIds;
  final int resolveVotes;
  final int quorum;
  final VoidCallback onJoin;
  final VoidCallback onVote;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AI FOST DISPECERIZAT',
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            joined
                ? 'Ești pe teren. Confirmă rezolvarea când intervenția e gata.'
                : 'Echipajul tău a fost alocat. Apasă Preia ca să te alături.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          if (joined) ...<Widget>[
            Text(
              'Alăturați: $joinedCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (joinedIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                joinedIds.map(_shortId).join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Progres vot: $resolveVotes / $quorum',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: (voted || voting) ? null : onVote,
                icon: voting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(voted ? Icons.check : Icons.task_alt),
                label: Text(
                  voted
                      ? 'Vot înregistrat'
                      : voting
                          ? 'Se votează…'
                          : 'Rezolvat',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ] else
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: joining ? null : onJoin,
                icon: joining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.handshake_outlined),
                label: Text(joining ? 'Se preia…' : 'Preia'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _shortId(String id) {
    if (id.length <= 14) return id;
    return '${id.substring(0, 12)}…';
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    this.filled = false,
  });

  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.15) : color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontSize: 13, height: 1.3),
          ),
        ),
      ],
    );
  }
}
