// Cheap, battery-friendly location: ONE balanced-power fix per report (no
// continuous tracking, no map SDK), cached for a couple of minutes.
//
// The fix is attached to IncidentLocation.lat/lng. Indoors/at a gate GPS is
// only a hint, so the human-readable place ("Sector 3", "Poarta 12") still
// comes from what the reporter says.

import 'package:geolocator/geolocator.dart';

class LocationFix {
  const LocationFix({
    required this.lat,
    required this.lng,
    this.accuracyMeters,
  });

  final double lat;
  final double lng;
  final double? accuracyMeters;

  String get label {
    final accuracy = accuracyMeters;
    return accuracy == null ? 'GPS' : 'GPS ±${accuracy.round()} m';
  }
}

abstract class LocationService {
  /// Best available position, or null (permission denied, GPS off, timeout).
  /// Never throws and never blocks longer than a few seconds.
  Future<LocationFix?> current();
}

class GeolocatorLocationService implements LocationService {
  static const Duration _cacheFor = Duration(minutes: 2);

  LocationFix? _cached;
  DateTime? _cachedAt;

  @override
  Future<LocationFix?> current() async {
    final cachedAt = _cachedAt;
    if (_cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _cacheFor) {
      return _cached;
    }
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _cached;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return _cached;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _cached = LocationFix(
        lat: position.latitude,
        lng: position.longitude,
        accuracyMeters: position.accuracy,
      );
      _cachedAt = DateTime.now();
      return _cached;
    } on Object {
      return _cached;
    }
  }
}
