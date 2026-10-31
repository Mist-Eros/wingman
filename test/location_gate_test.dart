import 'package:flutter_test/flutter_test.dart';
import 'package:wingman/core/location/location_gate.dart';

void main() {
  const airportLat = 44.3189;
  const airportLng = 23.8864;

  test('accepts a position inside the 2 km airport radius', () {
    final distance = AirportGeofence.distanceMeters(
      lat: airportLat + 0.01, // ~1.1 km north
      lng: airportLng,
      airportLat: airportLat,
      airportLng: airportLng,
    );
    expect(distance, lessThan(AirportGeofence.maxDistanceMeters));
    expect(
      AirportGeofence.isWithinRange(
        lat: airportLat + 0.01,
        lng: airportLng,
        airportLat: airportLat,
        airportLng: airportLng,
      ),
      isTrue,
    );
  });

  test('rejects a position outside the 2 km airport radius', () {
    final distance = AirportGeofence.distanceMeters(
      lat: airportLat + 0.03, // ~3.3 km north
      lng: airportLng,
      airportLat: airportLat,
      airportLng: airportLng,
    );
    expect(distance, greaterThan(AirportGeofence.maxDistanceMeters));
    expect(
      AirportGeofence.isWithinRange(
        lat: airportLat + 0.03,
        lng: airportLng,
        airportLat: airportLat,
        airportLng: airportLng,
      ),
      isFalse,
    );
  });
}
