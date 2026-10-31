import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme/wingman_theme.dart';

/// Small "people" chip in a ticket header: how many distinct people reported
/// the incident. The tooltip also shows the raw submission count (one person can
/// report the same incident more than once).
class ReporterCountChip extends StatelessWidget {
  const ReporterCountChip({super.key, required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final people = ticket.reporterPeopleCount;
    final reports = ticket.reportCount;
    final multiple = reports > 1 || people > 1;
    final color = multiple ? WingmanColors.navy : WingmanColors.muted;
    return Tooltip(
      message: '$reports raportări · $people persoane',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: multiple
              ? WingmanColors.navy.withValues(alpha: 0.08)
              : WingmanColors.surfaceMuted,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(
            color: multiple
                ? WingmanColors.navy.withValues(alpha: 0.18)
                : WingmanColors.line,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.people_alt_outlined,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 3),
            Text(
              '$people',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
