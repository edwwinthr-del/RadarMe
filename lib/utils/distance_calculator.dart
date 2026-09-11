import 'package:geolocator/geolocator.dart';

import '../config/constants.dart';
import '../models/radar.dart';

/// A radar paired with its measured distance from the driver.
class RadarDistance {
  const RadarDistance(this.radar, this.meters);

  final Radar radar;
  final double meters;
}

/// Great-circle distance helpers.
///
/// `Geolocator.distanceBetween` is a pure-Dart haversine implementation, so it
/// is equally usable on the UI isolate and inside the background isolate.
class DistanceCalculator {
  const DistanceCalculator._();

  static double metersBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) =>
      Geolocator.distanceBetween(startLat, startLng, endLat, endLng);

  static double toRadar(Radar radar, double latitude, double longitude) =>
      Geolocator.distanceBetween(latitude, longitude, radar.lat, radar.lng);

  /// Cheap lat/lng box test, run before any trigonometry.
  ///
  /// A full pass over every radar on each GPS fix would be wasted work: at
  /// 10 m granularity almost all of them are tens of kilometres away. Two
  /// subtractions per radar throw those out first.
  static bool isInBoundingBox(Radar radar, double latitude, double longitude) =>
      (latitude - radar.lat).abs() <= AppConstants.boundingBoxLatDegrees &&
      (longitude - radar.lng).abs() <= AppConstants.boundingBoxLngDegrees;

  /// Radars close enough to matter, measured and sorted nearest-first.
  ///
  /// The box spans ~5.5 km, so nothing inside the 1 km maximum alert radius
  /// (plus hysteresis) can ever be filtered out by mistake.
  static List<RadarDistance> candidatesNear({
    required List<Radar> radars,
    required double latitude,
    required double longitude,
  }) {
    final List<RadarDistance> candidates = <RadarDistance>[];
    for (final Radar radar in radars) {
      if (!isInBoundingBox(radar, latitude, longitude)) continue;
      candidates.add(
        RadarDistance(radar, toRadar(radar, latitude, longitude)),
      );
    }
    candidates.sort(_byDistance);
    return candidates;
  }

  /// Every radar within [radiusMeters], nearest first.
  static List<RadarDistance> withinRadius({
    required List<Radar> radars,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    bool Function(Radar radar)? where,
  }) {
    final List<RadarDistance> matches = <RadarDistance>[];
    for (final Radar radar in radars) {
      if (where != null && !where(radar)) continue;
      if (!isInBoundingBox(radar, latitude, longitude)) continue;
      final double meters = toRadar(radar, latitude, longitude);
      if (meters <= radiusMeters) matches.add(RadarDistance(radar, meters));
    }
    matches.sort(_byDistance);
    return matches;
  }

  /// Full scan, used by the list screen and as a fallback when the driver is
  /// outside every bounding box.
  static List<RadarDistance> sortedByDistance({
    required List<Radar> radars,
    required double latitude,
    required double longitude,
  }) {
    final List<RadarDistance> all = <RadarDistance>[
      for (final Radar radar in radars)
        RadarDistance(radar, toRadar(radar, latitude, longitude)),
    ];
    all.sort(_byDistance);
    return all;
  }

  static RadarDistance? nearest({
    required List<Radar> radars,
    required double latitude,
    required double longitude,
  }) {
    RadarDistance? best;
    for (final Radar radar in radars) {
      final double meters = toRadar(radar, latitude, longitude);
      if (best == null || meters < best.meters) {
        best = RadarDistance(radar, meters);
      }
    }
    return best;
  }

  static int _byDistance(RadarDistance a, RadarDistance b) =>
      a.meters.compareTo(b.meters);
}
