import 'package:geolocator/geolocator.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../models/user_settings.dart';
import '../utils/distance_calculator.dart';

enum SpeedZoneStatus { safe, borderline, over }

/// Live tracking state between point A and point B of one corridor.
class SpeedZoneSession {
  SpeedZoneSession({
    required this.zone,
    required this.enteredAt,
    required this.speedLimitKmh,
    required this.remainingMeters,
    required double latitude,
    required double longitude,
  })  : _lastLatitude = latitude,
        _lastLongitude = longitude;

  final SpeedZone zone;
  final DateTime enteredAt;
  final double speedLimitKmh;

  /// Ground distance covered since point A, summed from every GPS fix.
  double travelledMeters = 0;
  double remainingMeters;

  double _lastLatitude;
  double _lastLongitude;

  Duration elapsedAt(DateTime now) => now.difference(enteredAt);

  /// Average since entering. Recomputed from [now] so the figure keeps falling
  /// while the car is stopped, exactly as the enforcement system measures it.
  double averageSpeedKmh(DateTime now) {
    final int milliseconds = elapsedAt(now).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return travelledMeters * 3600 / milliseconds;
  }

  SpeedZoneStatus statusAt(DateTime now) {
    final double average = averageSpeedKmh(now);
    if (average > speedLimitKmh) return SpeedZoneStatus.over;
    if (average >= speedLimitKmh * AppConstants.speedZoneWarningFactor) {
      return SpeedZoneStatus.borderline;
    }
    return SpeedZoneStatus.safe;
  }

  void _advance({
    required double latitude,
    required double longitude,
    required double remaining,
  }) {
    travelledMeters += DistanceCalculator.metersBetween(
      _lastLatitude,
      _lastLongitude,
      latitude,
      longitude,
    );
    _lastLatitude = latitude;
    _lastLongitude = longitude;
    remainingMeters = remaining;
  }
}

/// Emitted once, when the driver reaches point B.
class SpeedZoneCompletion {
  const SpeedZoneCompletion({
    required this.zone,
    required this.averageKmh,
    required this.limitKmh,
  });

  final SpeedZone zone;
  final double averageKmh;
  final double limitKmh;

  bool get isOverLimit => averageKmh > limitKmh;
}

/// Watches the driver across average-speed corridors.
///
/// Kept apart from `ProximityProvider` for the same reason as
/// [ProximityEngine]: it is plain logic over positions, with no Flutter or
/// notifier machinery in the way.
class SpeedZoneTracker {
  /// The shortest corridor in the dataset is ~690 m, so the 500 m circles
  /// around point A and point B overlap. Without a floor on the sample, a
  /// session could start and finalise a fraction of a second later and divide
  /// a few metres by that sliver of time — reporting a wild average and
  /// alarming a driver who did nothing wrong. Below these thresholds the
  /// corridor is closed silently instead.
  static const double _minSampleMeters = 250;
  static const Duration _minSampleTime = Duration(seconds: 15);

  SpeedZoneSession? _session;

  /// Corridor just completed; ignored until the driver leaves its point A, so
  /// finishing a short zone does not immediately restart it.
  String? _suppressedZoneId;

  SpeedZoneSession? get session => _session;

  /// Advances tracking by one fix, returning a completion on reaching point B.
  SpeedZoneCompletion? update({
    required List<SpeedZone> zones,
    required Position position,
    required UserSettings settings,
  }) {
    final DateTime now = DateTime.now();
    final SpeedZoneSession? active = _session;

    if (active != null) {
      active._advance(
        latitude: position.latitude,
        longitude: position.longitude,
        remaining: DistanceCalculator.toRadar(
          active.zone.pointB,
          position.latitude,
          position.longitude,
        ),
      );

      if (active.remainingMeters <= AppConstants.speedZoneTriggerMeters) {
        _suppressedZoneId = active.zone.id;
        _session = null;

        final bool measurable = active.travelledMeters >= _minSampleMeters &&
            active.elapsedAt(now) >= _minSampleTime;
        if (!measurable) return null;

        return SpeedZoneCompletion(
          zone: active.zone,
          averageKmh: active.averageSpeedKmh(now),
          limitKmh: active.speedLimitKmh,
        );
      }
      if (active.elapsedAt(now) > AppConstants.speedZoneTimeout) {
        _session = null;
      }
      return null;
    }

    if (!settings.alertOnSpeedZone) return null;
    _releaseSuppressedZone(zones, position);

    for (final SpeedZone zone in zones) {
      if (zone.id == _suppressedZoneId) continue;
      final double toEntry = DistanceCalculator.toRadar(
        zone.pointA,
        position.latitude,
        position.longitude,
      );
      if (toEntry > AppConstants.speedZoneTriggerMeters) continue;

      // Already inside point B's circle: there is no corridor left to measure,
      // so starting a session here would only produce a meaningless reading.
      final double toExit = DistanceCalculator.toRadar(
        zone.pointB,
        position.latitude,
        position.longitude,
      );
      if (toExit <= AppConstants.speedZoneTriggerMeters) continue;

      _session = SpeedZoneSession(
        zone: zone,
        enteredAt: now,
        speedLimitKmh: settings.speedLimitFor(zone),
        remainingMeters: toExit,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      return null;
    }
    return null;
  }

  void reset() {
    _session = null;
    _suppressedZoneId = null;
  }

  void _releaseSuppressedZone(List<SpeedZone> zones, Position position) {
    final String? suppressed = _suppressedZoneId;
    if (suppressed == null) return;

    for (final SpeedZone zone in zones) {
      if (zone.id != suppressed) continue;
      final double toEntry = DistanceCalculator.toRadar(
        zone.pointA,
        position.latitude,
        position.longitude,
      );
      if (toEntry > AppConstants.speedZoneTriggerMeters) {
        _suppressedZoneId = null;
      }
      return;
    }
    // The corridor is gone from the dataset; stop suppressing it.
    _suppressedZoneId = null;
  }
}
