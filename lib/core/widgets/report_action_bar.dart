// =============================================================================
// lib/core/widgets/report_action_bar.dart
//
// The single, large "report incident" action at the bottom of the crew and
// dispatcher screens. Anyone using the app can report — keeping the action in
// a full-width bottom bar makes it the easiest thing to reach on a phone.
// =============================================================================

import 'package:flutter/material.dart';

class ReportActionBar extends StatelessWidget {
  const ReportActionBar({
    super.key,
    required this.onPressed,
    this.label = 'Raportează un incident',
  });

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: Colors.white,
      elevation: 14,
      shadowColor: const Color(0x33000000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: FilledButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.campaign_rounded, size: 28),
                  label: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
