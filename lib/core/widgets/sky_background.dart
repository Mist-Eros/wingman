// =============================================================================
// lib/core/widgets/sky_background.dart
//
// OWNER: Lead (lib/core/). Shared aerospace backdrop: a deep sky gradient,
// soft drifting clouds and a faint plane silhouette. Cheap (one painter, no
// assets) and safe on phones: it repaints a single CustomPaint layer.
//
// Use it for entry/empty surfaces (login, role picker, reporter idle). Don't
// wrap dense lists with it — cards should sit on the calm background instead.
// =============================================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/wingman_theme.dart';

class SkyBackground extends StatefulWidget {
  const SkyBackground({
    super.key,
    required this.child,
    this.animate = true,
    this.showGround = false,
  });

  final Widget child;

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
      duration: const Duration(seconds: 48),
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
  _SkyPainter({required this.progress, required this.showGround});

  final double progress;
  final bool showGround;

  static const List<Color> _skyColors = <Color>[
    Color(0xFF0C243F),
    Color(0xFF123A63),
    Color(0xFF1D4E89),
    Color(0xFF4F7FB5),
    Color(0xFFD9E8F7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final skyHeight = showGround ? size.height * 0.82 : size.height;

    // Sky gradient.
    final skyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _skyColors,
        stops: <double>[0.0, 0.22, 0.48, 0.72, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, skyHeight));
    canvas.drawRect(rect, skyPaint);

    // Sun glow, top-right.
    final glowCenter = Offset(size.width * 0.84, size.height * 0.12);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: <Color>[
          Colors.white.withValues(alpha: 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(center: glowCenter, radius: size.width * 0.55),
      );
    canvas.drawCircle(glowCenter, size.width * 0.55, glowPaint);

    // Drifting clouds (parallax: far clouds move slower).
    _cloud(canvas, size, x: _wrap(0.10 + progress * 0.6), y: 0.28, scale: 1.0,
        alpha: 0.16);
    _cloud(canvas, size, x: _wrap(0.55 + progress * 0.45), y: 0.16, scale: 0.7,
        alpha: 0.12);
    _cloud(canvas, size, x: _wrap(0.80 - progress * 0.5), y: 0.48, scale: 1.25,
        alpha: 0.10);
    _cloud(canvas, size, x: _wrap(0.32 - progress * 0.35), y: 0.62, scale: 0.55,
        alpha: 0.14);

    // Faint airliner crossing the sky.
    _plane(
      canvas,
      size,
      center: Offset(
        _wrap(0.15 + progress * 1.15) * size.width,
        size.height * 0.36,
      ),
      scale: size.width / 420,
    );

    if (showGround) {
      _ground(canvas, size);
    }
  }

  double _wrap(double value) => value - value.floorToDouble();

  void _cloud(
    Canvas canvas,
    Size size, {
    required double x,
    required double y,
    required double scale,
    required double alpha,
  }) {
    final paint = Paint()..color = Colors.white.withValues(alpha: alpha);
    final base = Offset(x * size.width, y * size.height);
    final unit = size.width * 0.06 * scale;
    canvas.drawCircle(base, unit * 1.1, paint);
    canvas.drawCircle(base + Offset(unit * 1.3, unit * 0.25), unit * 0.9, paint);
    canvas.drawCircle(base - Offset(unit * 1.2, unit * 0.15), unit * 0.75, paint);
    canvas.drawCircle(base + Offset(unit * 0.2, -unit * 0.6), unit * 0.7, paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: base + Offset(0, unit * 0.45),
        width: unit * 4.4,
        height: unit * 1.1,
      ),
      paint,
    );
  }

  void _plane(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double scale,
  }) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.35);
    final s = math.max(0.6, scale);
    final path = Path()
      ..moveTo(center.dx + 26 * s, center.dy)
      ..quadraticBezierTo(
        center.dx + 4 * s,
        center.dy - 5 * s,
        center.dx - 22 * s,
        center.dy - 2 * s,
      )
      // top wing
      ..lineTo(center.dx - 6 * s, center.dy - 16 * s)
      ..lineTo(center.dx - 1 * s, center.dy - 16 * s)
      ..lineTo(center.dx - 8 * s, center.dy - 1 * s)
      // tail
      ..lineTo(center.dx - 22 * s, center.dy - 9 * s)
      ..lineTo(center.dx - 27 * s, center.dy - 9 * s)
      ..lineTo(center.dx - 24 * s, center.dy + 1 * s)
      // bottom wing
      ..lineTo(center.dx - 8 * s, center.dy + 9 * s)
      ..lineTo(center.dx - 2 * s, center.dy + 9 * s)
      ..lineTo(center.dx - 9 * s, center.dy + 1 * s)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _ground(Canvas canvas, Size size) {
    final top = size.height * 0.82;
    final groundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          WingmanColors.navy.withValues(alpha: 0.85),
          const Color(0xFF081726),
        ],
      ).createShader(Rect.fromLTWH(0, top, size.width, size.height - top));
    canvas.drawRect(Rect.fromLTWH(0, top, size.width, size.height - top), groundPaint);

    // Runway light dashes for a subtle "airport at dusk" hint.
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: 0.22)
      ..strokeWidth = 2;
    final y = top + (size.height - top) * 0.45;
    for (double x = size.width * 0.08; x < size.width * 0.92; x += 34) {
      canvas.drawLine(Offset(x, y), Offset(x + 16, y), dash);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.showGround != showGround;
}
