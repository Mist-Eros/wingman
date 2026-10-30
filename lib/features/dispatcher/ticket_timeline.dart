import 'package:flutter/material.dart';

import '../../core/models/ticket.dart';
import 'urgency_style.dart';

class TicketTimeline extends StatelessWidget {
  const TicketTimeline({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final style = UrgencyStyle.of(ticket.urgency);
    final steps = _stepsFor(ticket);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Timeline',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < steps.length; i++) ...[
          _TimelineRow(
            step: steps[i],
            isLast: i == steps.length - 1,
            accent: style.accent,
          ),
        ],
      ],
    );
  }

  List<_TimelineStep> _stepsFor(Ticket ticket) {
    final steps = <_TimelineStep>[
      _TimelineStep(
        label: 'Creat',
        done: true,
        time: ticket.createdAt,
        detail: ticket.source.labelRo,
      ),
    ];

    if (ticket.confidence < 0.65 ||
        ticket.isPendingOverride ||
        ticket.overrideDeadline != null ||
        ticket.decidedBy != null) {
      steps.add(
        _TimelineStep(
          label: 'Override dispecer',
          done: !ticket.isPendingOverride,
          time: ticket.overrideDeadline,
          detail: ticket.isPendingOverride
              ? 'În fereastra de 5s'
              : (ticket.decidedBy == null
                  ? 'Expirat → auto'
                  : 'Decis de ${ticket.decidedBy}'),
          active: ticket.isPendingOverride,
        ),
      );
    }

    steps.add(
      _TimelineStep(
        label: 'Dispecerizat',
        done: ticket.status == TicketStatus.dispatched ||
            ticket.status == TicketStatus.inProgress ||
            ticket.status == TicketStatus.resolved,
        time: ticket.dispatchedAt,
        detail: ticket.decidedBy == null &&
                ticket.status != TicketStatus.pendingOverride &&
                ticket.status != TicketStatus.denied
            ? 'Auto-dispecerizat'
            : ticket.departmentsLabel,
      ),
    );

    steps.add(
      _TimelineStep(
        label: 'Echipaj pe teren',
        done: ticket.joinedCrewIds.isNotEmpty ||
            ticket.status == TicketStatus.inProgress ||
            ticket.status == TicketStatus.resolved,
        time: null,
        detail: ticket.joinedCrewIds.isEmpty
            ? 'Nimeni încă'
            : '${ticket.joinedCrewIds.length} join',
      ),
    );

    if (ticket.status == TicketStatus.denied) {
      steps.add(
        _TimelineStep(
          label: 'Respins',
          done: true,
          time: ticket.updatedAt,
          detail: ticket.resolutionNote ?? 'Fără notă',
          active: true,
        ),
      );
    } else {
      steps.add(
        _TimelineStep(
          label: 'Rezolvat',
          done: ticket.status == TicketStatus.resolved,
          time: ticket.resolvedAt,
          detail: 'Voturi ${ticket.resolveVotes}/${ticket.quorum}',
        ),
      );
    }

    return steps;
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.label,
    required this.done,
    this.time,
    this.detail,
    this.active = false,
  });

  final String label;
  final bool done;
  final DateTime? time;
  final String? detail;
  final bool active;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.step,
    required this.isLast,
    required this.accent,
  });

  final _TimelineStep step;
  final bool isLast;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = step.active
        ? const Color(0xFFD92D20)
        : (step.done ? accent : const Color(0xFF98A2B3));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Column(
          children: <Widget>[
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: step.done || step.active ? color : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: color.withValues(alpha: 0.35),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  step.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                if (step.detail != null)
                  Text(
                    step.detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (step.time != null)
                  Text(
                    _fmt(step.time!),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _fmt(DateTime dt) {
    final local = dt.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    return '$hh:$mm:$ss';
  }
}
