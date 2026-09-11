import '../config/constants.dart';
import '../models/radar.dart';
import '../utils/distance_calculator.dart';

/// Snapshot of the driver's surroundings for one GPS fix.
class ProximityResult {
  const ProximityResult({
    required this.inRange,
    required this.newAlerts,
    this.nearest,
  });

  /// Alertable radars currently inside the alert radius, nearest first.
  final List<RadarDistance> inRange;

  /// The subset of [inRange] that crossed the radius on this fix — exactly the
  /// radars an alarm should fire for.
  final List<RadarDistance> newAlerts;

  /// Closest radar of any type, ignoring the alert filters, for the always-on
  /// distance readout.
  final RadarDistance? nearest;

  static const ProximityResult empty = ProximityResult(
    inRange: <RadarDistance>[],
    newAlerts: <RadarDistance>[],
  );
}

/// The alarm state machine. Shared verbatim by [ProximityProvider] on the UI
/// isolate and by the background isolate so both behave identically.
///
/// It remembers which radars have already been announced and only releases one
/// once the driver is [hysteresisMeters] beyond the alert radius. Without that
/// buffer a car idling at a red light on the radius boundary would re-trigger
/// the alarm every time GPS noise nudged it across the line.
class ProximityEngine {
  ProximityEngine({this.hysteresisMeters = AppConstants.hysteresisMeters});

  final double hysteresisMeters;

  final Set<String> _announced = <String>{};

  int get announcedCount => _announced.length;

  bool wasAnnounced(String radarId) => _announced.contains(radarId);

  ProximityResult evaluate({
    required List<Radar> radars,
    required double latitude,
    required double longitude,
    required double radiusMeters,
    required bool Function(Radar radar) isAlertable,
  }) {
    if (radars.isEmpty) return ProximityResult.empty;

    final List<RadarDistance> candidates = DistanceCalculator.candidatesNear(
      radars: radars,
      latitude: latitude,
      longitude: longitude,
    );
    final Map<String, double> distanceById = <String, double>{
      for (final RadarDistance candidate in candidates)
        candidate.radar.id: candidate.meters,
    };

    // Release first, so a radar left behind can alarm again on a return trip.
    // A radar missing from the map fell out of the ~5.5 km bounding box, which
    // is well past the release threshold.
    _announced.removeWhere((String id) {
      final double? meters = distanceById[id];
      return meters == null || meters > radiusMeters + hysteresisMeters;
    });

    final List<RadarDistance> inRange = <RadarDistance>[];
    final List<RadarDistance> newAlerts = <RadarDistance>[];
    for (final RadarDistance candidate in candidates) {
      if (candidate.meters > radiusMeters) break; // candidates are sorted
      if (!isAlertable(candidate.radar)) continue;
      inRange.add(candidate);
      if (_announced.add(candidate.radar.id)) newAlerts.add(candidate);
    }

    // Nothing in the box means the nearest radar is far away; a single full
    // scan over 88 records is cheap and keeps the readout honest.
    final RadarDistance? nearest = candidates.isNotEmpty
        ? candidates.first
        : DistanceCalculator.nearest(
            radars: radars,
            latitude: latitude,
            longitude: longitude,
          );

    return ProximityResult(
      inRange: inRange,
      newAlerts: newAlerts,
      nearest: nearest,
    );
  }

  /// Forgets every announcement, e.g. after the alert radius or filters change.
  void reset() => _announced.clear();
}
