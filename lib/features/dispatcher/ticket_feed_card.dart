import 'package:flutter/material.dart';

import '../../core/incidents/likelihood.dart';
import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import '../../core/widgets/reporter_count_chip.dart';
import '../../core/widgets/ticket_timer.dart';
import '../../core/widgets/required_teams_bar.dart';
import '../../core/widgets/ticket_media_panel.dart';
import 'dispatcher_density.dart';
import 'urgency_style.dart';

/// Shared body used by feed cards and the override card.
class TicketCardBody extends StatelessWidget {
  const TicketCardBody({
    super.key,
    required this.ticket,
    this.compact = false,
    this.density = DispatcherDensity.comfortable,
  });

  final Ticket ticket;
  final bool compact;
  final DispatcherDensity density;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = UrgencyStyle.of(ticket.urgency);
    final standby = ticket.standbyDepartments.map((d) => d.labelRo).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          ticket.labelRo,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: style.onFill,
            height: 1.25,
            fontSize: density.titleSize,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ticket.incidentCode,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: style.accent,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _InfoPill(
                icon: Icons.place_outlined, label: ticket.location.display),
            _InfoPill(
                icon: Icons.groups_outlined, label: ticket.departmentsLabel),
            if (standby.isNotEmpty)
              _InfoPill(
                icon: Icons.notifications_paused_outlined,
                label: 'Standby: $standby',
              ),
            if (ticket.craiovaLikelihood < 0.70) const _WhyChip(),
          ],
        ),
        const SizedBox(height: 8),
        RequiredTeamsBar(ticket: ticket, compact: true),
        if (ticket.aiRationale != null &&
            ticket.aiRationale!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            ticket.aiRationale!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: style.onFill.withValues(alpha: 0.9),
              height: 1.35,
            ),
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        if (!compact) ...[
          const SizedBox(height: 10),
          Text(
            ticket.transcript.isEmpty
                ? 'Fără transcript'
                : '„${ticket.transcript}”',
            style: theme.textTheme.bodySmall?.copyWith(
              color: style.onFill.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

class _WhyChip extends StatelessWidget {
  const _WhyChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFD92D20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.help_outline, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Probabilitate Craiova < 70% · de verificat',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scannable ticket card — background color follows urgency.
class TicketFeedCard extends StatelessWidget {
  const TicketFeedCard({
    super.key,
    required this.ticket,
    this.selected = false,
    this.onTap,
    this.density = DispatcherDensity.comfortable,
    this.onDeny,
    this.onReclassify,
    this.busy = false,
  });

  final Ticket ticket;
  final bool selected;
  final VoidCallback? onTap;
  final DispatcherDensity density;
  final VoidCallback? onDeny;
  final VoidCallback? onReclassify;
  final bool busy;

  bool get _showActions =>
      !ticket.status.isTerminal &&
      !ticket.isPendingOverride &&
      (onDeny != null || onReclassify != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = UrgencyStyle.of(ticket.urgency);
    final dimmed = ticket.status.isTerminal;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: dimmed ? style.fill.withValues(alpha: 0.55) : style.fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? style.accent : style.accent.withValues(alpha: 0.35),
          width: selected ? 2.5 : 1.2,
        ),
        boxShadow: selected
            ? <BoxShadow>[
                BoxShadow(
                  color: style.accent.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ]
            : const <BoxShadow>[
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  width: 8,
                  decoration: BoxDecoration(
                    color: style.accent,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(13),
                      bottomLeft: Radius.circular(13),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: density.cardPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: <Widget>[
                                  _UrgencyBadge(urgency: ticket.urgency),
                                  _ConfidenceChip(
                                      likelihood: ticket.craiovaLikelihood),
                                  _StatusChip(status: ticket.status),
                                  ReporterCountChip(ticket: ticket),
                                  TicketTimerChip(ticket: ticket),
                                  Text(
                                    _ageLabel(ticket.ageSeconds()),
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color:
                                          style.onFill.withValues(alpha: 0.65),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _shortId(ticket.id),
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontFamily: 'Consolas',
                                fontWeight: FontWeight.w700,
                                color: style.onFill.withValues(alpha: 0.55),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(
                            height:
                                density == DispatcherDensity.compact ? 8 : 12),
                        TicketCardBody(
                          ticket: ticket,
                          density: density,
                        ),
                        SizedBox(
                            height:
                                density == DispatcherDensity.compact ? 8 : 12),
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.person_outline,
                              size: 16,
                              color: style.onFill.withValues(alpha: 0.65),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ticket.reporterName,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: style.onFill.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            _FooterStat(
                              icon: Icons.engineering_outlined,
                              text: '${ticket.joinedCrewIds.length}',
                              color: style.onFill,
                            ),
                            const SizedBox(width: 10),
                            _FooterStat(
                              icon: Icons.how_to_vote_outlined,
                              text: '${ticket.resolveVotes}/${ticket.quorum}',
                              color: style.onFill,
                            ),
                          ],
                        ),
                        if (ticket.decidedBy == null &&
                            ticket.status != TicketStatus.pendingOverride &&
                            ticket.status != TicketStatus.denied) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: style.fillStrong,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Auto-dispecerizat',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: style.onFill,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (ticket.photoBase64 != null ||
                            (ticket.location.lat != null &&
                                ticket.location.lng != null)) ...<Widget>[
                          const SizedBox(height: 10),
                          TicketMediaPanel(
                            ticket: ticket,
                            height: 150,
                            compact: true,
                          ),
                        ],
                        if (_showActions) ...[
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: <Widget>[
                              if (onDeny != null)
                                OutlinedButton.icon(
                                  onPressed: busy ? null : onDeny,
                                  icon: const Icon(Icons.cancel_outlined,
                                      size: 18),
                                  label: const Text('Respinge'),
                                ),
                              if (onReclassify != null)
                                OutlinedButton.icon(
                                  onPressed: busy ? null : onReclassify,
                                  icon: const Icon(Icons.swap_horiz, size: 18),
                                  label: const Text('Reclasifică'),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FooterStat extends StatelessWidget {
  const _FooterStat({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 15, color: color.withValues(alpha: 0.65)),
        const SizedBox(width: 3),
        Text(
          text,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _UrgencyBadge extends StatelessWidget {
  const _UrgencyBadge({required this.urgency});

  final Urgency urgency;

  @override
  Widget build(BuildContext context) {
    final style = UrgencyStyle.of(urgency);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.accent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        style.label.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  const _ConfidenceChip({required this.likelihood});

  final double likelihood;

  @override
  Widget build(BuildContext context) {
    final low = likelihood < 0.70;
    final color = low ? const Color(0xFFB42318) : const Color(0xFF027A48);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (low) ...[
            Icon(Icons.warning_amber_rounded, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            airportLikelihoodPercent(likelihood),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.labelRo,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: const Color(0xFF344054)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF344054),
                    fontWeight: FontWeight.w600,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

String _shortId(String id) {
  if (id.startsWith('demo-')) {
    final tail = id.replaceFirst('demo-', '');
    return tail.length <= 10
        ? tail.toUpperCase()
        : tail.substring(0, 10).toUpperCase();
  }
  final cleaned = id.replaceAll('-', '');
  if (cleaned.length <= 8) return id;
  return cleaned.substring(0, 8).toUpperCase();
}

String _ageLabel(int seconds) {
  if (seconds < 60) return 'acum ${seconds}s';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return 'acum $minutes min';
  final hours = minutes ~/ 60;
  return 'acum ${hours}h';
}
