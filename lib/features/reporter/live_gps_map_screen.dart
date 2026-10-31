// Real slippy map (OpenStreetMap tiles) with a live GPS marker and accuracy
// circle. Tile provider/center/zoom are driven by DomainConfig.map, so another
// application can point at a different area (or a self-hosted tile server)
// without touching this screen.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/core_scope.dart';
import '../../../core/theme/wingman_theme.dart';

class LiveGpsMapScreen extends StatefulWidget {
  const LiveGpsMapScreen({super.key});

  @override
  State<LiveGpsMapScreen> createState() => _LiveGpsMapScreenState();
}

class _LiveGpsMapScreenState extends State<LiveGpsMapScreen> {
  final MapController _mapController = MapController();
  StreamSubscription<Position>? _sub;
  Position? _position;
  String? _error;
  DateTime? _updatedAt;
  bool _mapReady = false;
  bool _follow = true;
  bool _movedOnce = false;

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
        setState(() => _error = 'Permisiunea de locație nu este acordatÄƒ.');
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
        _centerOn(position, force: !_movedOnce);
        _movedOnce = true;
      },
      onError: (Object error) {
        if (!mounted) return;
        setState(() => _error = 'GPS indisponibil: $error');
      },
    );
  }

  void _centerOn(Position position, {bool force = false}) {
    if (!_mapReady && !force) return;
    if (!_follow && !force) return;
    try {
      _mapController.move(
        LatLng(position.latitude, position.longitude),
        _mapController.camera.zoom,
      );
    } on Object {
      // Map is not ready yet; the next fix will center it.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final domain = CoreScope.domainOrFallbackOf(context);
    final config = domain.map;
    final position = _position;
    final center = position == null
        ? LatLng(config.initialLat, config.initialLng)
        : LatLng(position.latitude, position.longitude);

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
            icon: const Icon(Icons.gps_fixed_rounded),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: config.initialZoom,
              minZoom: 3,
              maxZoom: config.maxZoom,
              onMapReady: () {
                _mapReady = true;
                if (position != null) _centerOn(position, force: true);
              },
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture && _follow) {
                  setState(() => _follow = false);
                }
              },
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: config.tileUrl,
                userAgentPackageName: 'com.wingman.wingman',
                maxZoom: config.maxZoom,
                maxNativeZoom: config.maxZoom.toInt(),
              ),
              if (position != null)
                CircleLayer(
                  circles: <CircleMarker>[
                    CircleMarker(
                      point: LatLng(position.latitude, position.longitude),
                      radius: position.accuracy,
                      useRadiusInMeter: true,
                      color: WingmanColors.seed.withValues(alpha: 0.16),
                      borderColor: WingmanColors.seed.withValues(alpha: 0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              if (position != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: LatLng(position.latitude, position.longitude),
                      width: 42,
                      height: 42,
                      child: const _GpsMarker(),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: <SourceAttribution>[
                  TextSourceAttribution(
                    config.attribution,
                    prependCopyright: false,
                  ),
                ],
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StatusPill(
                    position: position,
                    error: _error,
                    provider: config.provider,
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: _LocationCard(
                          position: position,
                          updatedAt: _updatedAt,
                          error: _error,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton.small(
                        heroTag: 'recenter',
                        tooltip: 'CentreazÄƒ pe GPS',
                        onPressed: position == null
                            ? null
                            : () {
                                setState(() => _follow = true);
                                _centerOn(position, force: true);
                              },
                        child: Icon(
                          _follow
                              ? Icons.my_location
                              : Icons.location_searching,
                        ),
                      ),
                    ],
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

class _GpsMarker extends StatelessWidget {
  const _GpsMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFE11D48),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.position,
    required this.error,
    required this.provider,
  });

  final Position? position;
  final String? error;
  final String provider;

  @override
  Widget build(BuildContext context) {
    final ok = position != null;
    final color = ok
        ? WingmanColors.live
        : error != null
            ? WingmanColors.critical
            : WingmanColors.pending;
    final label = ok
        ? 'LIVE · ${providerLabel(provider)}'
        : error != null
            ? 'GPS indisponibil'
            : 'AȘTEPT GPS';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({
    required this.position,
    required this.updatedAt,
    required this.error,
  });

  final Position? position;
  final DateTime? updatedAt;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final pos = position;
    final age = updatedAt == null
        ? null
        : DateTime.now().difference(updatedAt!).inSeconds;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: WingmanColors.line),
        boxShadow: const <BoxShadow>[
          BoxShadow(
              color: Colors.black12, blurRadius: 12, offset: Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            pos == null
                ? (error ?? 'Aștept semnalul GPS…')
                : '${pos.latitude.toStringAsFixed(6)}, '
                    '${pos.longitude.toStringAsFixed(6)}',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          const SizedBox(height: 3),
          Text(
            pos == null
                ? 'Harta pornește pe centrul aeroportului. '
                    'Punctul roșu apare cÃ¢nd telefonul are poziÈ›ie.'
                : 'Precizie ±${pos.accuracy.toStringAsFixed(0)} m'
                    '${age == null ? '' : ' · actualizat acum ${age}s'}',
            style: const TextStyle(
              color: WingmanColors.muted,
              fontSize: 12,
            ),
          ),
          if (pos != null) ...<Widget>[
            const SizedBox(height: 2),
            const Text(
              'Marker roșu = poziția ta · cercul = precizia GPS. '
              'Apasă pe hartă pentru a naviga, butonul din dreapta te recentrează.',
              style: TextStyle(color: WingmanColors.muted, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

String providerLabel(String provider) {
  return switch (provider) {
    'openstreetmap' || 'osm' => 'OpenStreetMap',
    'google' => 'Google Maps',
    _ => provider,
  };
}
