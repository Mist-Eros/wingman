// Visible "who is needed" tags for a ticket. Used on dispatcher cards, crew
// cards, confirmation and details so the required departments are never hidden
// in a generic string.

import 'package:flutter/material.dart';

import '../incidents/taxonomy.dart';
import '../models/ticket.dart';
import '../theme/wingman_theme.dart';

class RequiredTeamsBar extends StatelessWidget {
  const RequiredTeamsBar({
    super.key,
    required this.ticket,
    this.compact = false,
    this.standby = true,
  });

  final Ticket ticket;
  final bool compact;
  final bool standby;

  @override
  Widget build(BuildContext context) {
    final required = ticket.primaryDepartments;
    final standbyDepts = ticket.standbyDepartments;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (!compact)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              'Echipe necesare',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: WingmanColors.muted,
              ),
            ),
          ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: <Widget>[
            if (compact)
              const Text(
                'Necesar:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: WingmanColors.muted,
                ),
              ),
            for (final department in required)
              _TeamTag(department: department, required: true),
          ],
        ),
        if (standby && standbyDepts.isNotEmpty && !compact) ...<Widget>[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              const Text(
                'Standby:',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: WingmanColors.muted,
                ),
              ),
              for (final department in standbyDepts)
                _TeamTag(department: department, required: false),
            ],
          ),
        ],
      ],
    );
  }
}

class _TeamTag extends StatelessWidget {
  const _TeamTag({required this.department, required this.required});

  final Department department;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: required
            ? WingmanColors.navy.withValues(alpha: 0.08)
            : WingmanColors.surfaceMuted,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: required
              ? WingmanColors.navy.withValues(alpha: 0.18)
              : WingmanColors.line,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            _iconFor(department),
            size: 13,
            color: required ? WingmanColors.navy : WingmanColors.muted,
          ),
          const SizedBox(width: 4),
          Text(
            department.labelRo,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: required ? FontWeight.w800 : FontWeight.w600,
              color: required ? WingmanColors.ink : WingmanColors.muted,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(Department department) => switch (department) {
      Department.medical => Icons.medical_services_outlined,
      Department.fireRescue => Icons.local_fire_department_outlined,
      Department.security => Icons.shield_outlined,
      Department.maintenance => Icons.build_outlined,
      Department.operations => Icons.settings_outlined,
      Department.terminal => Icons.business_outlined,
      Department.baggage => Icons.luggage_outlined,
      Department.it => Icons.router_outlined,
      Department.airside => Icons.flight_outlined,
    };
