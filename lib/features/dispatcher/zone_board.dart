import 'package:flutter/material.dart';

import '../../core/models/ticket.dart';
import 'dispatcher_history.dart';
import 'urgency_style.dart';

/// Mini „hartă” pe zone — listă grupată din location.zone / terminal.
class ZoneBoard extends StatelessWidget {
  const ZoneBoard({
    super.key,
    required this.tickets,
    this.onSelectZoneTicket,
  });

  final List<Ticket> tickets;
  final ValueChanged<Ticket>? onSelectZoneTicket;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = groupTicketsByZone(
      tickets.where((t) => !t.status.isTerminal).toList(),
    );

    if (groups.isEmpty) {
      return Text(
        'Nicio zonă activă.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final entry in groups.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        const Icon(Icons.place_outlined, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '${entry.value.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: <Widget>[
                        for (final ticket in entry.value)
                          ActionChip(
                            avatar: CircleAvatar(
                              backgroundColor:
                                  UrgencyStyle.of(ticket.urgency).accent,
                              radius: 6,
                            ),
                            label: Text(ticket.incidentCode),
                            onPressed: onSelectZoneTicket == null
                                ? null
                                : () => onSelectZoneTicket!(ticket),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
