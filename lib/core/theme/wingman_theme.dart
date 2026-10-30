// =============================================================================
// lib/core/theme/wingman_theme.dart
//
// OWNER: Lead (lib/core/). Single source of truth for the app's look.
//
// Design language: "airport operations calm" — deep navy for authority, a very
// light cool background so ticket cards read like paper, urgency carried ONLY by
// semantic colors (never by decoration), generous but tight radii, zero heavy
// shadows. Built on Material 3 so every feature screen inherits it for free.
//
// Rules for teammates/features:
//   • never hardcode a hex in a screen; use Theme.of(context) or WingmanColors
//   • urgency → WingmanTheme.urgencyColor / .urgencyFill
//   • status  → WingmanTheme.statusColor
//   • spacing/radii → WingmanSpacing / WingmanRadius
// =============================================================================

import 'package:flutter/material.dart';

import '../incidents/taxonomy.dart';
import '../models/ticket.dart';

/// Brand + semantic palette. One place to change the whole product.
abstract final class WingmanColors {
  // Brand
  static const Color seed = Color(0xFF1D4E89); // airport navy
  static const Color navy = Color(0xFF123A63);
  static const Color ink = Color(0xFF102038);
  static const Color muted = Color(0xFF5A6B84);
  static const Color line = Color(0xFFE1E7F1);
  static const Color background = Color(0xFFF5F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFEEF2F8);

  // Urgency (semantic, used everywhere)
  static const Color critical = Color(0xFFC62828);
  static const Color criticalFill = Color(0xFFFDECEC);
  static const Color high = Color(0xFFD84315);
  static const Color highFill = Color(0xFFFDEFE7);
  static const Color medium = Color(0xFF9A6A00);
  static const Color mediumFill = Color(0xFFFFF5D6);
  static const Color low = Color(0xFF2E7D32);
  static const Color lowFill = Color(0xFFEAF6EB);

  // Ticket status (used by dispatcher/crew)
  static const Color pending = Color(0xFF9A5B00);
  static const Color pendingFill = Color(0xFFFFF1DC);
  static const Color dispatched = Color(0xFF1565C0);
  static const Color dispatchedFill = Color(0xFFE8F1FD);
  static const Color inProgress = Color(0xFFB45309);
  static const Color inProgressFill = Color(0xFFFDECD8);
  static const Color resolved = Color(0xFF2E7D32);
  static const Color resolvedFill = Color(0xFFEAF6EB);
  static const Color denied = Color(0xFF5B6B82);
  static const Color deniedFill = Color(0xFFEEF1F5);

  // Accent for "live/WSS connected"
  static const Color live = Color(0xFF1B7F5A);
  static const Color liveFill = Color(0xFFE6F4EE);
}

/// Spacing scale (4-based). Use these instead of magic numbers.
abstract final class WingmanSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double page = 20; // standard horizontal page padding
}

/// Corner radii.
abstract final class WingmanRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
}

abstract final class WingmanTheme {
  static ColorScheme _scheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(
      seedColor: WingmanColors.seed,
      brightness: brightness,
    );
    return scheme.copyWith(
      primary: isLight ? WingmanColors.seed : const Color(0xFF8FB4E8),
      onPrimary: isLight ? Colors.white : const Color(0xFF04203C),
      secondary: isLight ? WingmanColors.navy : const Color(0xFFA9C6EC),
      surface: isLight ? WingmanColors.surface : const Color(0xFF141C28),
      onSurface: isLight ? WingmanColors.ink : const Color(0xFFE7EDF6),
      error: isLight ? WingmanColors.critical : const Color(0xFFFF8A80),
      outline: isLight ? WingmanColors.line : const Color(0xFF2A3748),
      outlineVariant: isLight ? WingmanColors.line : const Color(0xFF243040),
    );
  }

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = _scheme(brightness);
    final background =
        isLight ? WingmanColors.background : const Color(0xFF0C121B);
    final surface = isLight ? WingmanColors.surface : const Color(0xFF141C28);
    final ink = isLight ? WingmanColors.ink : const Color(0xFFE7EDF6);
    final muted = isLight ? WingmanColors.muted : const Color(0xFF9AA9BD);
    final line = isLight ? WingmanColors.line : const Color(0xFF26313F);

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      splashFactory: InkSparkle.splashFactory,
    );

    final textTheme = base.textTheme
        .apply(bodyColor: ink, displayColor: ink)
        .copyWith(
          displaySmall: base.textTheme.displaySmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6),
          headlineMedium: base.textTheme.headlineMedium
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.4),
          headlineSmall: base.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleLarge: base.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          titleMedium:
              base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          labelLarge:
              base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        );

    CardThemeData cardTheme() => CardThemeData(
          color: surface,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          elevation: 0,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: WingmanRadius.card,
            side: BorderSide(color: line),
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.headlineSmall?.copyWith(fontSize: 22),
        iconTheme: IconThemeData(color: ink),
      ),
      cardTheme: cardTheme(),
      dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: ink),
      listTileTheme: ListTileThemeData(
        iconColor: muted,
        textColor: ink,
        shape: const RoundedRectangleBorder(borderRadius: WingmanRadius.card),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WingmanRadius.md),
          ),
          textStyle: textTheme.labelLarge,
          padding: const EdgeInsets.symmetric(
            horizontal: WingmanSpacing.lg,
            vertical: WingmanSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          side: BorderSide(color: line),
          foregroundColor: ink,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WingmanRadius.md),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: WingmanSpacing.lg,
          vertical: WingmanSpacing.lg,
        ),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WingmanRadius.md),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WingmanRadius.md),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(WingmanRadius.md),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? WingmanColors.surfaceMuted : line,
        side: BorderSide(color: line),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: ink,
          fontWeight: FontWeight.w600,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WingmanRadius.xl),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(WingmanRadius.md),
        ),
        backgroundColor: isLight ? WingmanColors.ink : surface,
        contentTextStyle: TextStyle(color: isLight ? Colors.white : ink),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: line,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(WingmanRadius.xl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: (isLight ? WingmanColors.surfaceMuted : line),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelMedium),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: WingmanColors.ink,
          borderRadius: BorderRadius.circular(WingmanRadius.sm),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
    );
  }

  // ── semantic helpers (use these in features) ──────────────────────────────

  /// Text/border color for an urgency.
  static Color urgencyColor(Urgency urgency) => switch (urgency) {
        Urgency.critical => WingmanColors.critical,
        Urgency.high => WingmanColors.high,
        Urgency.medium => WingmanColors.medium,
        Urgency.low => WingmanColors.low,
      };

  /// Soft background for an urgency chip.
  static Color urgencyFill(Urgency urgency) => switch (urgency) {
        Urgency.critical => WingmanColors.criticalFill,
        Urgency.high => WingmanColors.highFill,
        Urgency.medium => WingmanColors.mediumFill,
        Urgency.low => WingmanColors.lowFill,
      };

  static Color statusColor(TicketStatus status) => switch (status) {
        TicketStatus.pendingOverride => WingmanColors.pending,
        TicketStatus.dispatched => WingmanColors.dispatched,
        TicketStatus.inProgress => WingmanColors.inProgress,
        TicketStatus.resolved => WingmanColors.resolved,
        TicketStatus.denied => WingmanColors.denied,
      };

  static Color statusFill(TicketStatus status) => switch (status) {
        TicketStatus.pendingOverride => WingmanColors.pendingFill,
        TicketStatus.dispatched => WingmanColors.dispatchedFill,
        TicketStatus.inProgress => WingmanColors.inProgressFill,
        TicketStatus.resolved => WingmanColors.resolvedFill,
        TicketStatus.denied => WingmanColors.deniedFill,
      };

  /// Card shadow used only for the "active/focused" surface (override card).
  static List<BoxShadow> softShadow = <BoxShadow>[
    BoxShadow(
      color: WingmanColors.navy.withValues(alpha: 0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}
