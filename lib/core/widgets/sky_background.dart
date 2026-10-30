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

    // Faint airliner crossing the sky (top-down silhouette, so it reads as a
    // plane instead of a blob).
    _plane(
      canvas,
      size,
      center: Offset(
        _wrap(0.15 + progress * 1.15) * size.width,
        size.height * 0.33,
      ),
      unit: size.width * 0.045,
      alpha: period.isNight ? 0.34 : 0.60,
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
  /// Top-down airliner: pointed fuselage, swept-back wings, tailplane and two
  /// engine nacelles. [unit] is roughly half the fuselage length in pixels.
  void _plane(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double unit,
    required double alpha,
  }) {
    final u = math.max(6.0, unit);
    final body = Path()
      ..moveTo(0, -1.05 * u) // nose
      ..cubicTo(0.16 * u, -0.72 * u, 0.17 * u, 0.45 * u, 0.11 * u, 0.86 * u)
      ..lineTo(0.06 * u, 1.02 * u)
      ..lineTo(-0.06 * u, 1.02 * u)
      ..lineTo(-0.11 * u, 0.86 * u)
      ..cubicTo(-0.17 * u, 0.45 * u, -0.16 * u, -0.72 * u, 0, -1.05 * u)
      ..close();

    final wing = Path()
      ..moveTo(0.11 * u, -0.05 * u)
      ..lineTo(0.95 * u, 0.52 * u)
      ..lineTo(0.95 * u, 0.66 * u)
      ..lineTo(0.11 * u, 0.30 * u)
      ..close();

    final tail = Path()
      ..moveTo(0.10 * u, 0.62 * u)
      ..lineTo(0.44 * u, 0.82 * u)
      ..lineTo(0.44 * u, 0.91 * u)
      ..lineTo(0.10 * u, 0.78 * u)
      ..close();

    final engine = Rect.fromCenter(
      center: Offset(0.40 * u, 0.28 * u),
      width: 0.12 * u,
      height: 0.28 * u,
    );

    void draw(Offset offset, Paint paint) {
      canvas.save();
      canvas.translate(center.dx + offset.dx, center.dy + offset.dy);
      canvas.drawPath(body, paint);
      canvas.drawPath(wing, paint);
      canvas.drawOval(engine, paint);
      canvas.save();
      canvas.scale(-1, 1);
      canvas.drawPath(wing, paint);
      canvas.drawOval(engine, paint);
      canvas.restore();
      canvas.drawPath(tail, paint);
      canvas.save();
      canvas.scale(-1, 1);
      canvas.drawPath(tail, paint);
      canvas.restore();
      canvas.restore();
    }

    // Soft drop shadow so the white silhouette reads on light skies too.
    draw(Offset(2, 5),
        Paint()..color = Colors.black.withValues(alpha: alpha * 0.14));
    draw(Offset.zero, Paint()..color = Colors.white.withValues(alpha: alpha));
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
