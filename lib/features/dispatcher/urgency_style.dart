import 'package:flutter/material.dart';

import '../../core/incidents/taxonomy.dart';

/// Visual language for urgency — used on cards, legend, and filters.
class UrgencyStyle {
  const UrgencyStyle({
    required this.accent,
    required this.fill,
    required this.fillStrong,
    required this.onFill,
    required this.label,
  });

  final Color accent;
  final Color fill;
  final Color fillStrong;
  final Color onFill;
  final String label;

  static UrgencyStyle of(Urgency urgency) => switch (urgency) {
        Urgency.critical => const UrgencyStyle(
            accent: Color(0xFFD92D20),
            fill: Color(0xFFFEE4E2),
            fillStrong: Color(0xFFFECDCA),
            onFill: Color(0xFF7A271A),
            label: 'Critică',
          ),
        Urgency.high => const UrgencyStyle(
            accent: Color(0xFFDC6803),
            fill: Color(0xFFFFF1E3),
            fillStrong: Color(0xFFFEDF89),
            onFill: Color(0xFF7A2E0E),
            label: 'Ridicată',
          ),
        Urgency.medium => const UrgencyStyle(
            accent: Color(0xFFCA8A04),
            fill: Color(0xFFFEF9C3),
            fillStrong: Color(0xFFFEF08A),
            onFill: Color(0xFF713F12),
            label: 'Medie',
          ),
        Urgency.low => const UrgencyStyle(
            accent: Color(0xFF1570EF),
            fill: Color(0xFFEFF8FF),
            fillStrong: Color(0xFFD1E9FF),
            onFill: Color(0xFF194185),
            label: 'Scăzută',
          ),
      };
}

/// Soft page background for the dispatcher desktop shell.
const Color kDispatcherCanvas = Color(0xFFF4F6F9);
const Color kDispatcherSidebar = Color(0xFFEEF2F6);
