// Live GPS map for the reporter. Uses the real location stream and draws the
// position on a schematic Craiova airport map, with the accuracy circle and
// raw coordinates. No network map tiles — this works offline on the venue Wi-Fi.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/theme/wingman_theme.dart';

class LiveGpsMapScreen extends StatefulWidget {
  const LiveGpsMapScreen({super.key});

  @override
  State<LiveGpsMapScreen> createState() => _LiveGpsMapScreenState();
}

class _LiveGpsMapScreenState extends State<LiveGpsMapScreen> {
  StreamSubscription<Position>? _sub;
  Position? _position;
  String? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      if (mounted) setState(() => _error = 'Serviciul de locație este oprit.');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _error = 'Permisiunea de locație nu este acordată.');
      }
      return;
    }
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 1,
      ),
    ).listen(
      (position) {
        if (!mounted) return;
        setState(() {
          _position = position;
          _updatedAt = DateTime.now();
          _error = null;
        });
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _error = 'GPS indisponibil: $error');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final position = _position;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hartă live · GPS'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reia GPS',
            onPressed: () {
              _sub?.cancel();
              _start();
            },
            icon: const Icon(Icons.my_location),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0F7),
                borderRadius: BorderRadius.circular(WingmanRadius.lg),
                border: Border.all(color: WingmanColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: position == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const CircularProgressIndicator(),
                            const SizedBox(height: 14),
                            Text(
                              _error ??
                                  'Aștept semnalul GPS…\n'
                                      'Punctul apare când telefonul are poziție.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : CustomPaint(
                      painter: _AirportMapPainter(position: position),
                      size: Size.infinite,
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    position == null
                        ? 'Locație în așteptare'
                        : '${position.latitude.toStringAsFixed(6)}, '
                            '${position.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position == null
                        ? 'Pornește GPS-ul pentru poziția live.'
                        : 'Precizie ±${position.accuracy.toStringAsFixed(0)} m · '
                            'actualizat acum '
                            '${DateTime.now().difference(_updatedAt ?? DateTime.now()).inSeconds}s',
                    style: TextStyle(color: WingmanColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Punctul se mișcă în timp real. Cercul arată precizia GPS; '
                    'cu cât e mai mic, cu atât locația e mai exactă.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirportMapPainter extends CustomPainter {
  _AirportMapPainter({required this.position});

  final Position position;

  static const double _latMin = 44.308;
  static const double _latMax = 44.331;
  static const double _lngMin = 23.868;
  static const double _lngMax = 23.906;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFFEAF0F7);
    canvas.drawRect(Offset.zero & size, bg);

    // Grid
    final grid = Paint()
      ..color = const Color(0xFFD6E1EE)
      ..strokeWidth = 1;
    for (var i = 1; i < 6; i++) {
      final x = size.width * i / 6;
      final y = size.height * i / 6;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    // Runway 09/27 (diagonal), taxiway, apron/terminal blocks.
    final runway = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.30),
      Offset(size.width * 0.86, size.height * 0.70),
      runway,
    );
    final centerline = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(size.width * 0.14, size.height * 0.30),
      Offset(size.width * 0.86, size.height * 0.70),
      centerline,
    );
    final taxiway = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.62),
      Offset(size.width * 0.62, size.height * 0.52),
      taxiway,
    );
    final building = Paint()..color = const Color(0xFFCBD5E1);
    final terminal = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.55, size.height * 0.62, size.width * 0.28,
          size.height * 0.10),
      const Radius.circular(8),
    );
    canvas.drawRRect(terminal, building);
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.58, size.height * 0.74, size.width * 0.18,
          size.height * 0.08),
      building,
    );

    _label(canvas, 'CRAIOVA · TERMINAL', size.width * 0.56, size.height * 0.64);
    _label(canvas, 'PISTĂ 09/27', size.width * 0.44, size.height * 0.47);

    // Real GPS position mapped to airport bounds.
    final nx = ((position.longitude - _lngMin) / (_lngMax - _lngMin))
        .clamp(0.03, 0.97);
    final ny = (1 - (position.latitude - _latMin) / (_latMax - _latMin))
        .clamp(0.03, 0.97);
    final point = Offset(size.width * nx, size.height * ny);

    // Accuracy circle: metres -> pixels using the longitude span.
    final metresPerPixel = (_lngMax - _lngMin) * 111320 / size.width;
    final radius = (position.accuracy / metresPerPixel).clamp(8.0, 140.0);

    canvas.drawCircle(
      point,
      radius,
      Paint()..color = WingmanColors.seed.withValues(alpha: 0.16),
    );
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = WingmanColors.seed.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(point, 10, Paint()..color = Colors.white);
    canvas.drawCircle(
      point,
      7,
      Paint()..color = const Color(0xFFE11D48),
    );
  }

  void _label(Canvas canvas, String text, double x, double y) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, Offset(x, y));
  }

  @override
  bool shouldRepaint(covariant _AirportMapPainter oldDelegate) =>
      oldDelegate.position.latitude != position.latitude ||
      oldDelegate.position.longitude != position.longitude ||
      oldDelegate.position.accuracy != position.accuracy;
}
