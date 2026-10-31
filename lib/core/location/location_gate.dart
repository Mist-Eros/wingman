import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../theme/wingman_theme.dart';

/// Pure distance helper so the geofence is unit-testable without a device.
class AirportGeofence {
  const AirportGeofence._();

  static const double maxDistanceMeters = 2000;
  static const double _earthRadiusMeters = 6371000;

  static double distanceMeters({
    required double lat,
    required double lng,
    required double airportLat,
    required double airportLng,
  }) {
    final dLat = _radians(airportLat - lat);
    final dLng = _radians(airportLng - lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat)) *
            math.cos(_radians(airportLat)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * _earthRadiusMeters * math.asin(math.sqrt(a));
  }

  static bool isWithinRange({
    required double lat,
    required double lng,
    required double airportLat,
    required double airportLng,
  }) =>
      distanceMeters(
        lat: lat,
        lng: lng,
        airportLat: airportLat,
        airportLng: airportLng,
      ) <=
      maxDistanceMeters;

  static double _radians(double degrees) => degrees * math.pi / 180;
}

/// Locks the signed-in app until the phone is within 2 km of the airport and
/// location services + permission are available.
class LocationGate extends StatefulWidget {
  const LocationGate({
    super.key,
    required this.airportLat,
    required this.airportLng,
    required this.child,
    this.onSignOut,
    this.bypassUntilMillis = 0,
  });

  final double airportLat;
  final double airportLng;
  final Widget child;
  final VoidCallback? onSignOut;

  /// Temporary demo escape hatch. A build with a future epoch here bypasses the
  /// gate until that instant, then automatically re-locks.
  final int bypassUntilMillis;

  @override
  State<LocationGate> createState() => _LocationGateState();
}

enum _GateStatus {
  checking,
  ok,
  serviceOff,
  permissionDenied,
  outside,
  unavailable
}

class _LocationGateState extends State<LocationGate>
    with WidgetsBindingObserver {
  _GateStatus _status = _GateStatus.checking;
  double? _distance;
  bool _inFlight = false;
  bool _retryQueued = false;
  Position? _lastGoodPosition;
  DateTime? _lastGoodAt;
  bool _askedPermission = false;
  bool _allowWithoutLocation = false;
  Timer? _timer;
  Timer? _bypassTimer;

  bool get _bypassed =>
      widget.bypassUntilMillis > DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_bypassed) {
      final remaining =
          widget.bypassUntilMillis - DateTime.now().millisecondsSinceEpoch;
      _bypassTimer = Timer(Duration(milliseconds: remaining), () {
        if (!mounted) return;
        setState(() {});
        unawaited(_check());
      });
      return;
    }
    unawaited(_check());
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_check(silent: true));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bypassTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_check(silent: true));
    }
  }

  Future<void> _check({bool silent = false, bool force = false}) async {
    if (_inFlight) {
      // A periodic check may be waiting on a 10 s GPS timeout. Never let a
      // user tap on "Reîncearcă" be swallowed; queue one forced re-check.
      if (force) _retryQueued = true;
      return;
    }
    _inFlight = true;
    if (!silent && mounted) {
      setState(() => _status = _GateStatus.checking);
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _set(_GateStatus.serviceOff);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && !_askedPermission) {
        _askedPermission = true;
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _set(_GateStatus.permissionDenied);
        return;
      }
      Position? position = await _acquirePosition();
      if (position == null) {
        // Keep a recently successful fix instead of flapping the lock on a
        // transient 10 s timeout while the phone is indoors.
        final good = _lastGoodPosition;
        final at = _lastGoodAt;
        if (good != null &&
            at != null &&
            DateTime.now().difference(at) < const Duration(minutes: 5)) {
          position = good;
        }
      }
      if (position == null) {
        _set(_GateStatus.unavailable);
        return;
      }
      _lastGoodPosition = position;
      _lastGoodAt = DateTime.now();
      final distance = AirportGeofence.distanceMeters(
        lat: position.latitude,
        lng: position.longitude,
        airportLat: widget.airportLat,
        airportLng: widget.airportLng,
      );
      _distance = distance;
      _set(
        distance <= AirportGeofence.maxDistanceMeters
            ? _GateStatus.ok
            : _GateStatus.outside,
      );
    } on TimeoutException {
      _set(_GateStatus.unavailable);
    } on LocationServiceDisabledException {
      _set(_GateStatus.serviceOff);
    } on PermissionDeniedException {
      _set(_GateStatus.permissionDenied);
    } on Object {
      _set(_GateStatus.unavailable);
    } finally {
      _inFlight = false;
      if (_retryQueued && mounted) {
        _retryQueued = false;
        unawaited(_check(force: true));
      }
    }
  }

  Future<void> _retry() async {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_check(silent: true));
    });
    await _check(force: true);
  }

  Future<Position?> _acquirePosition() async {
    // 1) Fresh cached fix (network/fused) — instant when available.
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null &&
          DateTime.now().difference(last.timestamp).abs() <
              const Duration(minutes: 5)) {
        return last;
      }
    } on Object catch (error) {
      debugPrint('[gate] last-known failed: $error');
    }

    // 2) Current fix, low accuracy first (network/cell is enough for a 2 km
    // geofence and works better indoors than a GPS-only high-accuracy fix).
    for (final accuracy in <LocationAccuracy>[
      LocationAccuracy.low,
      LocationAccuracy.medium,
    ]) {
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: LocationSettings(
            accuracy: accuracy,
            timeLimit: const Duration(seconds: 8),
          ),
        );
      } on Object catch (error) {
        debugPrint('[gate] current ($accuracy) failed: $error');
      }
    }

    // 3) First stream tick (some devices only wake the fused provider when a
    // listener is attached).
    try {
      return await Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 0,
        ),
      ).first.timeout(const Duration(seconds: 10));
    } on Object catch (error) {
      debugPrint('[gate] stream failed: $error');
    }
    return null;
  }

  void _set(_GateStatus status) {
    if (!mounted) return;
    setState(() {
      _status = status;
      if (status == _GateStatus.serviceOff ||
          status == _GateStatus.permissionDenied ||
          status == _GateStatus.outside) {
        _allowWithoutLocation = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bypassed) return widget.child;
    if (_status == _GateStatus.ok) return widget.child;
    if (_status == _GateStatus.unavailable && _allowWithoutLocation) {
      return widget.child;
    }
    return Scaffold(
      backgroundColor: WingmanColors.navy,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(
                      _status == _GateStatus.serviceOff
                          ? Icons.location_off_rounded
                          : _status == _GateStatus.outside
                              ? Icons.wrong_location_outlined
                              : Icons.my_location_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  if (_status == _GateStatus.outside && _distance != null) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Distanță estimată: ${(_distance! / 1000).toStringAsFixed(1)} km',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (_status == _GateStatus.checking)
                    const CircularProgressIndicator(color: Colors.white)
                  else ...<Widget>[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reîncearcă'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: WingmanColors.navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_status == _GateStatus.serviceOff) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: Geolocator.openLocationSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Deschide setările de locație'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                    if (_status == _GateStatus.permissionDenied) ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: Geolocator.openAppSettings,
                          icon: const Icon(Icons.settings_outlined),
                          label: const Text('Deschide setările aplicației'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.5),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ],
                  ],
                  if (_status == _GateStatus.unavailable) ...<Widget>[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _allowWithoutLocation = true),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text(
                        'Continuă fără verificarea locației',
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                  if (widget.onSignOut != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: widget.onSignOut,
                      child: Text(
                        'Ieși din cont',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String get _title {
    switch (_status) {
      case _GateStatus.serviceOff:
        return 'Locația este oprită';
      case _GateStatus.permissionDenied:
        return 'Permisiune de locație necesară';
      case _GateStatus.outside:
        return 'În afara razei aeroportului';
      case _GateStatus.unavailable:
        return 'Nu pot determina locația';
      case _GateStatus.checking:
      case _GateStatus.ok:
        return 'Verific locația…';
    }
  }

  String get _message {
    switch (_status) {
      case _GateStatus.serviceOff:
        return 'Pornește serviciul de locație al telefonului pentru a putea folosi aplicația.';
      case _GateStatus.permissionDenied:
        return 'Aplicația are nevoie de acces la locație. Permite accesul din setările aplicației.';
      case _GateStatus.outside:
        return 'Trebuie să fii în raza de ${AirportGeofence.maxDistanceMeters ~/ 1000} km a aeroportului pentru a raporta sau prelua incidente.';
      case _GateStatus.unavailable:
        return 'Nu am putut obține o poziție GPS. Ieși la cer deschis și încearcă din nou.';
      case _GateStatus.checking:
      case _GateStatus.ok:
        return 'Se verifică poziția telefonului…';
    }
  }
}
