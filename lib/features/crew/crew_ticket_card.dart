import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import '../../core/widgets/reporter_count_chip.dart';
import '../../core/widgets/ticket_timer.dart';
import '../../core/widgets/required_teams_bar.dart';
import '../../core/widgets/ticket_media_panel.dart';

/// One dispatched / in-progress ticket with Preia + Rezolvat actions.
class CrewTicketCard extends StatefulWidget {
  const CrewTicketCard({
    super.key,
    required this.ticket,
    required this.crewId,
    required this.onJoin,
    required this.onVote,
    required this.onLeave,
    this.lastActionError,
  });

  final Ticket ticket;
  final String crewId;
  final Future<bool> Function() onJoin;
  final Future<bool> Function() onVote;
  final Future<bool> Function() onLeave;
  final String? Function()? lastActionError;

  @override
  State<CrewTicketCard> createState() => _CrewTicketCardState();
}

class _CrewTicketCardState extends State<CrewTicketCard> {
  bool _joining = false;
  bool _voting = false;
  bool _leaving = false;
  bool _expanded = false;

  Ticket get _ticket => widget.ticket;
  bool get _joined => _ticket.isJoinedBy(widget.crewId);
  bool get _voted => _ticket.hasVotedBy(widget.crewId);
  bool get _busy => _joining || _voting || _leaving;

  /// Card accent must follow URGENCY, never the category: a medium spill
  /// belongs to Maintenance but still has a yellow card.
  Color get _accent {
    switch (_ticket.urgency) {
      case Urgency.critical:
        return const Color(0xFFD92D20);
      case Urgency.high:
        return const Color(0xFFDC6803);
      case Urgency.medium:
        return const Color(0xFFCA8A04);
      case Urgency.low:
        return const Color(0xFF2E7D32);
    }
  }

  Color get _urgencyColor => _accent;

  Future<void> _onJoin() async {
    if (_joined || _busy) return;
    setState(() => _joining = true);
    final ok = await widget.onJoin();
    if (!mounted) return;
    setState(() {
      _joining = false;
      if (ok) _expanded = true;
    });
    if (!ok) {
      _showError(
        widget.lastActionError?.call() ?? 'Nu am putut prelua intervenția.',
      );
    }
  }

  Future<void> _onVote() async {
    if (!_joined || _voted || _busy) return;
    setState(() => _voting = true);
    final ok = await widget.onVote();
    if (!mounted) return;
    setState(() => _voting = false);
    if (!ok) {
      _showError(
        widget.lastActionError?.call() ?? 'Votul nu a putut fi înregistrat.',
      );
    }
  }

  Future<void> _onLeave() async {
    if (!_joined || _busy || _ticket.status.isTerminal) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Retragi intervenția?'),
        content: const Text(
          'Ai apăsat din greșeală „Preia”? Te scoatem din tichet, '
          'votul tău se șterge, iar tichetul revine în coadă.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rămân'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retrage-mă'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _leaving = true);
    final ok = await widget.onLeave();
    if (!mounted) return;
    setState(() {
      _leaving = false;
      if (ok) _expanded = false;
    });
    if (!ok) {
      _showError(
        widget.lastActionError?.call() ?? 'Nu am putut retrage intervenția.',
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFB3261E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final joinedCount = _ticket.joinedCrewIds.length;
    final voteProgress = _ticket.quorum == 0
        ? 0.0
        : (_ticket.resolveVotes / _ticket.quorum).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _expanded = !_expanded),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Container(width: 5, color: _accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                                      style:
                                          theme.textTheme.labelLarge?.copyWith(
                                        color: _accent,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _ticket.labelRo,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AnimatedRotation(
                                turns: _expanded ? 0.5 : 0,
                                duration: const Duration(milliseconds: 220),
                                child: Icon(
                                  Icons.expand_more_rounded,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
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
                                color: const Color(0xFF64748B),
                              ),
                              ReporterCountChip(ticket: _ticket),
                              TicketTimerChip(ticket: _ticket),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _MetaRow(
                            icon: Icons.place_outlined,
                            text: _ticket.location.display,
                          ),
                          const SizedBox(height: 8),
                          RequiredTeamsBar(ticket: _ticket),
                          const SizedBox(height: 6),
                          _MetaRow(
                            icon: Icons.groups_outlined,
                            text: joinedCount == 0
                                ? 'Nimeni nu a preluat încă'
                                : '$joinedCount ${joinedCount == 1 ? 'membru alăturat' : 'membri alăturați'}',
                          ),
                          const SizedBox(height: 6),
                          _MetaRow(
                            icon: Icons.how_to_vote_outlined,
                            text:
                                'Voturi: ${_ticket.resolveVotes}/${_ticket.quorum}',
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: voteProgress,
                              minHeight: 5,
                              backgroundColor: _accent.withValues(alpha: 0.12),
                              color: _accent,
                            ),
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 260),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _expanded
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 14),
                                    child: Column(
                                      children: <Widget>[
                                        TicketMediaPanel(
                                          ticket: _ticket,
                                          height: 160,
                                          compact: true,
                                        ),
                                        const SizedBox(height: 10),
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
                                          onLeave: _onLeave,
                                          leaving: _leaving,
                                          accent: _accent,
                                        ),
                                      ],
                                    ),
                                  )
                                : (!_joined
                                    ? Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.icon(
                                            onPressed: _busy
                                                ? null
                                                : () {
                                                    setState(
                                                      () => _expanded = true,
                                                    );
                                                    _onJoin();
                                                  },
                                            icon: _joining
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  )
                                                : const Icon(
                                                    Icons.handshake_outlined,
                                                  ),
                                            label: Text(
                                              _joining ? 'Se preia…' : 'Preia',
                                            ),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 13,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                    : Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: SizedBox(
                                          width: double.infinity,
                                          child: FilledButton.tonalIcon(
                                            onPressed: (_voted || _busy)
                                                ? null
                                                : _onVote,
                                            icon: _voting
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                                  )
                                                : Icon(
                                                    _voted
                                                        ? Icons
                                                            .check_circle_outline
                                                        : Icons.task_alt,
                                                  ),
                                            label: Text(
                                              _voted
                                                  ? 'Ai votat (${_ticket.resolveVotes}/${_ticket.quorum})'
                                                  : 'Rezolvat',
                                            ),
                                            style: FilledButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                vertical: 13,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          ),
                                        ),
                                      )),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
    required this.onLeave,
    required this.leaving,
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
  final VoidCallback onLeave;
  final bool leaving;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress =
        quorum == 0 ? 0.0 : (resolveVotes / quorum).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'AI FOST DISPECERIZAT',
            style: theme.textTheme.labelLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            joined
                ? 'Ești pe teren. Confirmă rezolvarea când intervenția e gata.'
                : 'Echipajul tău a fost alocat. Apasă Preia ca să te alături.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          if (joined) ...<Widget>[
            Text(
              'Alăturați: $joinedCount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: const Color(0xFF0F172A),
              ),
            ),
            if (joinedIds.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                joinedIds.map(_shortId).join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Text(
                  'Progres vot',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                Text(
                  '$resolveVotes / $quorum',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: accent.withValues(alpha: 0.14),
                color: accent,
              ),
            ),
            const SizedBox(height: 14),
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: (leaving || voting) ? null : onLeave,
              icon: leaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.undo_rounded, size: 18),
              label: Text(
                leaving
                    ? 'Se retrage…'
                    : 'Uh oh, am apăsat din greșeală — retrage-mă',
                style: const TextStyle(fontSize: 12),
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
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.14)
            : color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: color.withValues(alpha: filled ? 0.28 : 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.15,
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF475569),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
