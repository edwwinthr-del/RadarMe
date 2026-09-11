import 'package:flutter_test/flutter_test.dart';
import 'package:radarme/models/radar.dart';
import 'package:radarme/models/user_settings.dart';
import 'package:radarme/services/speed_zone_tracker.dart';

import 'test_helpers.dart';

void main() {
  const double baseLat = 42.30;
  const double baseLng = 19.20;
  const UserSettings settings = UserSettings.defaults;

  /// A corridor whose points are [lengthMeters] apart along a meridian.
  SpeedZone corridor(double lengthMeters) => SpeedZone(
        pointA: radarAt(
          id: '007',
          lat: baseLat,
          lng: baseLng,
          type: RadarType.averageSpeedControlA,
          pairedWith: '008',
        ),
        pointB: radarAt(
          id: '008',
          lat: latOffsetBy(baseLat, lengthMeters),
          lng: baseLng,
          type: RadarType.averageSpeedControlB,
          pairedWith: '007',
        ),
      );

  group('SpeedZoneTracker', () {
    test('starts a session on reaching point A of a long corridor', () {
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      final List<SpeedZone> zones = <SpeedZone>[corridor(4000)];

      final SpeedZoneCompletion? result = tracker.update(
        zones: zones,
        position: fixAt(baseLat, baseLng),
        settings: settings,
      );

      expect(result, isNull);
      expect(tracker.session, isNotNull);
      expect(tracker.session!.zone.pointA.id, '007');
      expect(tracker.session!.remainingMeters, closeTo(4000, 50));
    });

    test('refuses to start when already inside point B', () {
      // 690 m is the shortest real corridor in the dataset; with a 500 m
      // trigger at each end the two circles overlap in the middle.
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      final List<SpeedZone> zones = <SpeedZone>[corridor(690)];

      // Standing 400 m along: inside A's circle *and* inside B's.
      tracker.update(
        zones: zones,
        position: fixAt(latOffsetBy(baseLat, 400), baseLng),
        settings: settings,
      );

      expect(
        tracker.session,
        isNull,
        reason: 'no corridor left to measure, so no session should open',
      );
    });

    test('does not start when speed-zone alerts are switched off', () {
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      tracker.update(
        zones: <SpeedZone>[corridor(4000)],
        position: fixAt(baseLat, baseLng),
        settings: settings.copyWith(alertOnSpeedZone: false),
      );
      expect(tracker.session, isNull);
    });

    test('suppresses a completed corridor until point A is left behind', () {
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      final List<SpeedZone> zones = <SpeedZone>[corridor(4000)];

      tracker.update(
        zones: zones,
        position: fixAt(baseLat, baseLng),
        settings: settings,
      );
      expect(tracker.session, isNotNull);

      // Arrive within 500 m of B: the session finalises.
      tracker.update(
        zones: zones,
        position: fixAt(latOffsetBy(baseLat, 3700), baseLng),
        settings: settings,
      );
      expect(tracker.session, isNull);

      // Driving back through A's circle must not restart it immediately…
      tracker.update(
        zones: zones,
        position: fixAt(latOffsetBy(baseLat, 200), baseLng),
        settings: settings,
      );
      expect(tracker.session, isNull, reason: 'corridor is suppressed');

      // …until the driver has genuinely left point A, which lifts suppression.
      tracker.update(
        zones: zones,
        position: fixAt(latOffsetBy(baseLat, -2000), baseLng),
        settings: settings,
      );
      // Now returning to A opens a fresh session.
      tracker.update(
        zones: zones,
        position: fixAt(baseLat, baseLng),
        settings: settings,
      );
      expect(tracker.session, isNotNull);
    });

    test('a sample too small to judge yields no completion', () {
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      final List<SpeedZone> zones = <SpeedZone>[corridor(4000)];

      tracker.update(
        zones: zones,
        position: fixAt(baseLat, baseLng),
        settings: settings,
      );

      // Jump straight to B. Distance is large but elapsed time is ~0, so the
      // average would be nonsense — the tracker must stay silent.
      final SpeedZoneCompletion? completion = tracker.update(
        zones: zones,
        position: fixAt(latOffsetBy(baseLat, 3600), baseLng),
        settings: settings,
      );

      expect(
        completion,
        isNull,
        reason: 'must not alarm on an unmeasurably short sample',
      );
      expect(tracker.session, isNull);
    });

    test('reset clears session and suppression', () {
      final SpeedZoneTracker tracker = SpeedZoneTracker();
      tracker.update(
        zones: <SpeedZone>[corridor(4000)],
        position: fixAt(baseLat, baseLng),
        settings: settings,
      );
      expect(tracker.session, isNotNull);

      tracker.reset();
      expect(tracker.session, isNull);
    });
  });

  group('SpeedZoneSession', () {
    SpeedZoneSession session({
      required int elapsedSeconds,
      required double travelled,
      double limit = 80,
    }) {
      final SpeedZoneSession s = SpeedZoneSession(
        zone: corridor(4000),
        enteredAt: DateTime.now().subtract(Duration(seconds: elapsedSeconds)),
        speedLimitKmh: limit,
        remainingMeters: 1000,
        latitude: baseLat,
        longitude: baseLng,
      );
      s.travelledMeters = travelled;
      return s;
    }

    test('average speed is distance over elapsed time', () {
      // 1 km in 60 s = 60 km/h.
      final SpeedZoneSession s = session(elapsedSeconds: 60, travelled: 1000);
      expect(s.averageSpeedKmh(DateTime.now()), closeTo(60, 1));
    });

    test('average keeps falling while the car is stopped', () {
      final SpeedZoneSession s = session(elapsedSeconds: 60, travelled: 1000);
      final DateTime now = DateTime.now();
      final double moving = s.averageSpeedKmh(now);
      // Same distance, more time elapsed → lower average.
      final double later = s.averageSpeedKmh(now.add(const Duration(seconds: 60)));
      expect(later, lessThan(moving));
      expect(later, closeTo(30, 1));
    });

    test('status thresholds: safe, borderline, over', () {
      // 80 km/h limit; borderline starts at 90% = 72 km/h.
      expect(
        session(elapsedSeconds: 60, travelled: 1000).statusAt(DateTime.now()),
        SpeedZoneStatus.safe, // 60 km/h
      );
      expect(
        session(elapsedSeconds: 60, travelled: 1250).statusAt(DateTime.now()),
        SpeedZoneStatus.borderline, // 75 km/h
      );
      expect(
        session(elapsedSeconds: 60, travelled: 1500).statusAt(DateTime.now()),
        SpeedZoneStatus.over, // 90 km/h
      );
    });

    test('a zero-length elapsed window reports zero, not infinity', () {
      final SpeedZoneSession s = SpeedZoneSession(
        zone: corridor(4000),
        enteredAt: DateTime.now(),
        speedLimitKmh: 80,
        remainingMeters: 4000,
        latitude: baseLat,
        longitude: baseLng,
      );
      s.travelledMeters = 500;
      final double average = s.averageSpeedKmh(s.enteredAt);
      expect(average, 0);
      expect(average.isFinite, isTrue);
    });
  });

  group('UserSettings', () {
    test('urban corridors take the urban limit', () {
      final SpeedZone urban = SpeedZone(
        pointA: radarAt(
          id: '055',
          lat: baseLat,
          lng: baseLng,
          type: RadarType.averageSpeedControlA,
        ),
        pointB: radarAt(
          id: '056',
          lat: latOffsetBy(baseLat, 1000),
          lng: baseLng,
          type: RadarType.averageSpeedControlB,
        ),
      );
      // The helper names locations "Test lokacija <id>", which is not urban.
      expect(urban.isUrban, isFalse);
      expect(settings.speedLimitFor(urban), settings.ruralSpeedLimitKmh);
    });

    test('alertsFor maps every radar type', () {
      for (final RadarType type in RadarType.values) {
        expect(settings.alertsFor(type), isTrue);
      }
      final UserSettings muted = settings.copyWith(alertOnSpeedZone: false);
      expect(muted.alertsFor(RadarType.averageSpeedControlA), isFalse);
      expect(muted.alertsFor(RadarType.averageSpeedControlB), isFalse);
      expect(muted.alertsFor(RadarType.roadEnforcementPoint), isTrue);
    });
  });
}
