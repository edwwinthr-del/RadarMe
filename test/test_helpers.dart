import 'package:geolocator/geolocator.dart';
import 'package:radarme/models/radar.dart';

/// Builds a radar at an exact position, with only the fields tests care about.
Radar radarAt({
  required String id,
  required double lat,
  required double lng,
  RadarType type = RadarType.roadEnforcementPoint,
  RadarStatus status = RadarStatus.completed,
  String? pairedWith,
  String city = 'PODGORICA',
}) =>
    Radar(
      id: id,
      name: 'Test lokacija $id',
      city: city,
      type: type,
      status: status,
      lat: lat,
      lng: lng,
      capabilities: const <String>['instant_speed'],
      cameras: const <CameraUnit>[],
      pairedWith: pairedWith,
    );

/// A GPS fix. Only latitude/longitude/timestamp matter to the logic under test.
Position fixAt(double lat, double lng, {DateTime? at}) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: at ?? DateTime.now(),
      accuracy: 5,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

/// Metres per degree of latitude, near enough for building test fixtures.
const double metersPerDegreeLat = 111320;

/// A latitude [meters] north of [lat] — used to place radars at known
/// distances without hand-computing coordinates.
double latOffsetBy(double lat, double meters) => lat + meters / metersPerDegreeLat;
