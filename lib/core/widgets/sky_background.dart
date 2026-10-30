// =============================================================================
// lib/core/widgets/sky_background.dart
//
// OWNER: Lead (lib/core/). Time-of-day aerospace backdrop:
//   dawn → sunrise pink, morning → fresh blue, midday → bright azure,
//   afternoon → warm teal, sunset → orange/purple, night → deep navy + stars.
//
// The period is picked from the device clock (or forced with
// `--dart-define=SKY_PERIOD=night` for deterministic demo screenshots).
// Clouds are solid white (requested: no translucent overlapping circles).
// DevTools lets you preview every period without changing the clock.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// One of the six looks of the day.
enum SkyPeriod {
  dawn('Zori', <Color>[Color(0xFF2B1B4D), Color(0xFF6B4A8A), Color(0xFFD98BA0), Color(0xFFF7C79A)]),
  morning('Dimineață', <Color>[Color(0xFF123A63), Color(0xFF2F6FA8), Color(0xFF8CC4E8), Color(0xFFE6F3FB)]),
  midday('Amiază', <Color>[Color(0xFF0E3A66), Color(0xFF1E6FB8), Color(0xFF63B3E8), Color(0xFFDDF1FF)]),
  afternoon('După-amiază', <Color>[Color(0xFF153E66), Color(0xFF2C7CB5), Color(0xFF83C3DF), Color(0xFFF6E7C8)]),
  sunset('Apus', <Color>[Color(0xFF2A1A3E), Color(0xFF7A3B5E), Color(0xFFD96A4E), Color(0xFFF7B267)]),
  night('Noapte', <Color>[Color(0xFF040A18), Color(0xFF0A1B33), Color(0xFF123A63), Color(0xFF1E4B7A)]);

  const SkyPeriod(this.labelRo, this.skyColors);

  final String labelRo;

  /// Sky gradient, top → horizon (4 stops).
  final List<Color> skyColors;

  bool get isNight => this == SkyPeriod.night;
  bool get hasStars => this == SkyPeriod.night || this == SkyPeriod.dawn;
  bool get warmSun => this == SkyPeriod.dawn || this == SkyPeriod.sunset;

  /// Map a local hour (0-23) to the matching look.
  static SkyPeriod forHour(int hour) {
    if (hour >= 5 && hour < 7) return SkyPeriod.dawn;
    if (hour >= 7 && hour < 11) return SkyPeriod.morning;
    if (hour >= 11 && hour < 16) return SkyPeriod.midday;
    if (hour >= 16 && hour < 18) return SkyPeriod.afternoon;
    if (hour >= 18 && hour < 20) return SkyPeriod.sunset;
    return SkyPeriod.night;
  }

  /// The period to render now (honours the SKY_PERIOD compile-time override).
  static SkyPeriod current({DateTime? at}) {
    const override = String.fromEnvironment('SKY_PERIOD');
    if (override.isNotEmpty) {
      for (final period in SkyPeriod.values) {
        if (period.name == override.trim().toLowerCase()) return period;
      }
    }
    final now = at ?? DateTime.now();
    return forHour(now.hour);
  }
}

class SkyBackground extends StatefulWidget {
  const SkyBackground({
    super.key,
    required this.child,
    this.period,
    this.animate = true,
    this.showGround = false,
  });

  final Widget child;

  /// Force a specific look (DevTools preview); null = follow the clock.
  final SkyPeriod? period;

  /// Set false in tests / when the surface is static.
  final bool animate;

  /// Adds a soft runway/ground band at the bottom (login screen).
  final bool showGround;

  @override
  State<SkyBackground> createState() => _SkyBackgroundState();
}

class _SkyBackgroundState extends State<SkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    );
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant SkyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => CustomPaint(
          painter: _SkyPainter(
            progress: _controller.value,
            period: widget.period ?? SkyPeriod.current(),
            showGround: widget.showGround,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.progress,
    required this.period,
    required this.showGround,
  });

  final double progress;
  final SkyPeriod period;
  final bool showGround;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final skyHeight = showGround ? size.height * 0.82 : size.height;
    final colors = period.skyColors;

    // Sky gradient, top → horizon.
    final skyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: const <double>[0.0, 0.35, 0.68, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, skyHeight));
    canvas.drawRect(rect, skyPaint);

    // Stars at night/dawn.
    if (period.hasStars) {
      _stars(canvas, size, glow: period.isNight ? 1.0 : 0.45);
    }

    // Sun (all day looks) or moon (night), top-right.
    if (period.isNight) {
      _moon(canvas, size);
    } else {
      _sun(canvas, size, warm: period.warmSun);
    }

    // Drifting solid-white clouds (parallax).
    _cloud(canvas, size, x: _wrap(0.10 + progress * 0.6), y: 0.30, scale: 1.05);
    _cloud(canvas, size, x: _wrap(0.55 + progress * 0.45), y: 0.17, scale: 0.72);
    _cloud(canvas, size, x: _wrap(0.82 - progress * 0.5), y: 0.50, scale: 1.3);
    _cloud(canvas, size, x: _wrap(0.32 - progress * 0.35), y: 0.64, scale: 0.58);

    // Faint airliner crossing the sky.
    _plane(
      canvas,
      size,
      center: Offset(
        _wrap(0.15 + progress * 1.15) * size.width,
        size.height * 0.36,
      ),
      scale: size.width / 420,
      alpha: period.isNight ? 0.32 : 0.55,
    );

    if (showGround) _ground(canvas, size);
  }

  double _wrap(double value) => value - value.floorToDouble();

  // ── sun / moon ─────────────────────────────────────────────────────────────
  void _sun(Canvas canvas, Size size, {required bool warm}) {
    final center = Offset(size.width * 0.82, size.height * 0.14);
    final radius = size.width * (warm ? 0.5 : 0.45);
    final tint = warm ? const Color(0xFFFFD9A0) : Colors.white;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[tint.withValues(alpha: 0.62), tint.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      size.width * 0.035,
      Paint()..color = tint.withValues(alpha: warm ? 0.9 : 0.75),
    );
  }

  void _moon(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.82, size.height * 0.15);
    final radius = size.width * 0.06;

    // Soft glow.
    canvas.drawCircle(
      center,
      size.width * 0.5,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            Colors.white.withValues(alpha: 0.16),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.5)),
    );

    // True crescent: draw a full disc in a layer, then cut the bite out with
    // dstOut so the night sky shows through (no black circle on top).
    final discRect = Rect.fromCircle(center: center, radius: radius);
    canvas.saveLayer(discRect.inflate(radius), Paint());
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[const Color(0xFFF7FAFF), const Color(0xFFD9E4F5)],
        ).createShader(discRect),
    );
    canvas.drawCircle(
      center + Offset(radius * 0.62, -radius * 0.30),
      radius * 0.92,
      Paint()..blendMode = BlendMode.dstOut,
    );
    canvas.restore();
  }

  List<Color> get colors => period.skyColors;

  // ── stars ──────────────────────────────────────────────────────────────────
  void _stars(Canvas canvas, Size size, {required double glow}) {
    final random = math.Random(7);
    final paint = Paint();
    for (var i = 0; i < 46; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height * 0.62;
      final base = 0.6 + random.nextDouble() * 2.2;
      final twinkle =
          0.55 + 0.45 * math.sin((progress * 2 * math.pi) + i * 0.7).abs();
      paint.color = Colors.white.withValues(alpha: (0.25 + 0.55 * twinkle) * glow);
      canvas.drawCircle(Offset(x, y), base * 0.7, paint);
    }
  }

  // ── clouds (solid white, soft shadow) ─────────────────────────────────────
  void _cloud(
    Canvas canvas,
    Size size, {
    required double x,
    required double y,
    required double scale,
  }) {
    final base = Offset(x * size.width, y * size.height);
    final unit = size.width * 0.055 * scale;
    final puffs = <({double dx, double dy, double r})>[
      (dx: 0, dy: 0, r: 1.15),
      (dx: 1.35, dy: 0.22, r: 0.92),
      (dx: -1.25, dy: 0.12, r: 0.78),
      (dx: 0.25, dy: -0.62, r: 0.76),
      (dx: -0.55, dy: -0.35, r: 0.62),
      (dx: 1.0, dy: -0.3, r: 0.6),
    ];

    void draw(Offset offset, Color color) {
      final paint = Paint()..color = color;
      for (final puff in puffs) {
        canvas.drawCircle(
          base + Offset(puff.dx * unit, puff.dy * unit) + offset,
          puff.r * unit,
          paint,
        );
      }
      canvas.drawOval(
        Rect.fromCenter(
          center: base + Offset(0, unit * 0.5) + offset,
          width: unit * 4.6,
          height: unit * 1.25,
        ),
        paint,
      );
    }

    // Soft shadow under the cloud, then SOLID WHITE cloud on top.
    draw(Offset(2, unit * 0.22), Colors.black.withValues(alpha: 0.10));
    draw(Offset.zero, Colors.white);
  }

  // ── plane ──────────────────────────────────────────────────────────────────
  void _plane(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double scale,
    required double alpha,
  }) {
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
    final s = math.max(0.6, scale);
    final path = Path()
      ..moveTo(center.dx + 26 * s, center.dy)
      ..quadraticBezierTo(
        center.dx + 4 * s,
        center.dy - 5 * s,
        center.dx - 22 * s,
        center.dy - 2 * s,
      )
      ..lineTo(center.dx - 6 * s, center.dy - 16 * s)
      ..lineTo(center.dx - 1 * s, center.dy - 16 * s)
      ..lineTo(center.dx - 8 * s, center.dy - 1 * s)
      ..lineTo(center.dx - 22 * s, center.dy - 9 * s)
      ..lineTo(center.dx - 27 * s, center.dy - 9 * s)
      ..lineTo(center.dx - 24 * s, center.dy + 1 * s)
      ..lineTo(center.dx - 8 * s, center.dy + 9 * s)
      ..lineTo(center.dx - 2 * s, center.dy + 9 * s)
      ..lineTo(center.dx - 9 * s, center.dy + 1 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  // ── ground ─────────────────────────────────────────────────────────────────
  void _ground(Canvas canvas, Size size) {
    final top = size.height * 0.82;
    final deep = period.isNight ? const Color(0xFF040A12) : const Color(0xFF0B1D31);
    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[deep.withValues(alpha: 0.92), const Color(0xFF050B14)],
      ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top));
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, size.height - top), groundPaint);

    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 2;
    final y = top + (size.height - top) * 0.45;
    for (double x = size.width * 0.08; x < size.width * 0.92; x += 34) {
      canvas.drawLine(Offset(x, y), Offset(x + 16, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.period != period ||
      oldDelegate.showGround != showGround;
}

/// Small helper for surfaces that want the current look but only need its tint.
SkyPeriod currentSkyPeriod() => SkyPeriod.current();

/// Convenience accent for text placed on top of the sky.
Color skyOnSurface([SkyPeriod? period]) => Colors.white;

/// Re-export for screens that show the label ("Dimineață", "Apus", ...).
String skyPeriodLabel([SkyPeriod? period]) =>
    (period ?? SkyPeriod.current()).labelRo;
