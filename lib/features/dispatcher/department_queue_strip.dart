import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';
import '../../core/models/ticket.dart';
import '../../core/state/ticket_board.dart';
import 'urgency_style.dart';

/// Compact strip: how many active tickets are routed per department.
class DepartmentQueueStrip extends StatelessWidget {
  const DepartmentQueueStrip({
    super.key,
    required this.tickets,
    this.selected,
    this.onSelect,
  });

  /// Prefer passing the visible source list (live board or demo).
  final List<Ticket> tickets;
  final Department? selected;
  final ValueChanged<Department?>? onSelect;

  factory DepartmentQueueStrip.fromBoard({
    Key? key,
    required TicketBoard board,
    Department? selected,
    ValueChanged<Department?>? onSelect,
  }) {
    return DepartmentQueueStrip(
      key: key,
      tickets: board.tickets,
      selected: selected,
      onSelect: onSelect,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <(Department, int)>[];
    for (final dept in Department.values) {
      final count = tickets
          .where(
            (t) =>
                t.status.isActive &&
                (t.primaryDepartments.contains(dept) ||
                    t.standbyDepartments.contains(dept)),
          )
          .length;
      if (count > 0) entries.add((dept, count));
    }

    if (entries.isEmpty) {
      return Text(
        'Nicio coadă pe departamente încă.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected == entry.$1,
                avatar: CircleAvatar(
                  backgroundColor: selected == entry.$1
                      ? Colors.white
                      : const Color(0xFFD0D5DD),
                  child: Text(
                    '${entry.$2}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1D2939),
                    ),
                  ),
                ),
                label: Text(entry.$1.labelRo),
                onSelected: onSelect == null
                    ? null
                    : (value) => onSelect!(value ? entry.$1 : null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Quick urgency counts for the top of the feed.
class UrgencySummaryBar extends StatelessWidget {
  const UrgencySummaryBar({
    super.key,
    required this.tickets,
    this.selected,
    this.onSelect,
  });

  final List<Ticket> tickets;
  final Urgency? selected;
  final ValueChanged<Urgency?>? onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final urgency in Urgency.values.reversed) ...[
          Expanded(
            child: _UrgencyStatTile(
              urgency: urgency,
              count: tickets.where((t) => t.urgency == urgency).length,
              selected: selected == urgency,
              onTap: onSelect == null
                  ? null
                  : () => onSelect!(selected == urgency ? null : urgency),
            ),
          ),
          if (urgency != Urgency.low) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _UrgencyStatTile extends StatelessWidget {
  const _UrgencyStatTile({
    required this.urgency,
    required this.count,
    required this.selected,
    this.onTap,
  });

  final Urgency urgency;
  final int count;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final style = UrgencyStyle.of(urgency);
    return Material(
      color: selected ? style.fillStrong : style.fill,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? style.accent
                  : style.accent.withValues(alpha: 0.25),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                style.label,
                style: TextStyle(
                  color: style.onFill,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count',
                style: TextStyle(
                  color: style.accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
