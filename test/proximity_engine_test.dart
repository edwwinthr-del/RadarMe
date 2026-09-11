import 'package:flutter_test/flutter_test.dart';
import 'package:radarme/config/constants.dart';
import 'package:radarme/models/radar.dart';
import 'package:radarme/services/proximity_engine.dart';
import 'package:radarme/utils/distance_calculator.dart';

import 'test_helpers.dart';

/// Default predicate: every radar is alertable. Top level so it can be used as
/// a constant default parameter value.
bool alertAll(Radar _) => true;

void main() {
  const double baseLat = 42.44;
  const double baseLng = 19.25;
  const double radius = 300;

  ProximityResult evaluate(
    ProximityEngine engine,
    List<Radar> radars,
    double lat, {
    bool Function(Radar) isAlertable = alertAll,
  }) =>
      engine.evaluate(
        radars: radars,
        latitude: lat,
        longitude: baseLng,
        radiusMeters: radius,
        isAlertable: isAlertable,
      );

  group('ProximityEngine', () {
    test('announces a radar inside the radius exactly once', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
      ];

      // 100 m away — inside the 300 m radius.
      final double approach = latOffsetBy(baseLat, 100);

      final ProximityResult first = evaluate(engine, radars, approach);
      expect(first.newAlerts, hasLength(1));
      expect(first.newAlerts.single.radar.id, '001');
      expect(first.inRange, hasLength(1));

      // Same spot again: still in range, but no second alarm.
      final ProximityResult second = evaluate(engine, radars, approach);
      expect(second.newAlerts, isEmpty);
      expect(second.inRange, hasLength(1));
    });

    test('does not re-announce inside the hysteresis buffer', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
      ];

      evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(engine.wasAnnounced('001'), isTrue);

      // 350 m out: past the radius, but inside radius + 100 m hysteresis.
      evaluate(engine, radars, latOffsetBy(baseLat, 350));
      expect(
        engine.wasAnnounced('001'),
        isTrue,
        reason: 'still held while within the hysteresis buffer',
      );

      // Back inside — must stay silent, this is the idling-at-a-light case.
      final ProximityResult back = evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(back.newAlerts, isEmpty);
    });

    test('re-announces once the driver clears radius + hysteresis', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
      ];

      evaluate(engine, radars, latOffsetBy(baseLat, 100));

      // 500 m out: beyond 300 + 100, so the radar is released.
      evaluate(engine, radars, latOffsetBy(baseLat, 500));
      expect(engine.wasAnnounced('001'), isFalse);

      // Returning alarms again.
      final ProximityResult again = evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(again.newAlerts, hasLength(1));
    });

    test('releases a radar left far behind, outside the bounding box', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
      ];

      evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(engine.announcedCount, 1);

      // 20 km away — no longer a candidate at all.
      evaluate(engine, radars, latOffsetBy(baseLat, 20000));
      expect(
        engine.announcedCount,
        0,
        reason: 'a radar that falls out of the box must not stay latched',
      );
    });

    test('respects the per-type alert filter', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(
          id: '001',
          lat: baseLat,
          lng: baseLng,
          type: RadarType.intersectionEnforcement,
        ),
      ];

      final ProximityResult muted = evaluate(
        engine,
        radars,
        latOffsetBy(baseLat, 100),
        isAlertable: (Radar r) => r.type != RadarType.intersectionEnforcement,
      );

      expect(muted.newAlerts, isEmpty);
      expect(muted.inRange, isEmpty);
      expect(
        muted.nearest?.radar.id,
        '001',
        reason: 'the readout ignores alert filters',
      );
    });

    test('reports the nearest radar even when none are in range', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
        radarAt(id: '002', lat: latOffsetBy(baseLat, 3000), lng: baseLng),
      ];

      // 1 km from 001 and 2 km from 002, both outside the 300 m radius.
      final ProximityResult result = evaluate(engine, radars, latOffsetBy(baseLat, 1000));
      expect(result.inRange, isEmpty);
      expect(result.newAlerts, isEmpty);
      expect(result.nearest?.radar.id, '001');
      expect(result.nearest!.meters, closeTo(1000, 25));
    });

    test('falls back to a full scan when the bounding box is empty', () {
      final ProximityEngine engine = ProximityEngine();
      // 50 km north — far outside the ~5.5 km box.
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: latOffsetBy(baseLat, 50000), lng: baseLng),
      ];

      final ProximityResult result = evaluate(engine, radars, baseLat);
      expect(result.inRange, isEmpty);
      expect(
        result.nearest?.radar.id,
        '001',
        reason: 'nearest still resolves via the full-scan fallback',
      );
    });

    test('sorts in-range radars nearest first', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: 'far', lat: latOffsetBy(baseLat, 250), lng: baseLng),
        radarAt(id: 'near', lat: latOffsetBy(baseLat, 50), lng: baseLng),
      ];

      final ProximityResult result = evaluate(engine, radars, baseLat);
      expect(result.inRange.map((RadarDistance d) => d.radar.id), <String>['near', 'far']);
    });

    test('reset clears every announcement', () {
      final ProximityEngine engine = ProximityEngine();
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
      ];

      evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(engine.announcedCount, 1);

      engine.reset();
      expect(engine.announcedCount, 0);

      final ProximityResult after = evaluate(engine, radars, latOffsetBy(baseLat, 100));
      expect(after.newAlerts, hasLength(1));
    });

    test('empty radar list is handled', () {
      final ProximityEngine engine = ProximityEngine();
      final ProximityResult result = evaluate(engine, const <Radar>[], baseLat);
      expect(result.inRange, isEmpty);
      expect(result.newAlerts, isEmpty);
      expect(result.nearest, isNull);
    });
  });

  group('DistanceCalculator', () {
    test('bounding box spans further than the maximum alert radius', () {
      final Radar radar = radarAt(id: '001', lat: baseLat, lng: baseLng);
      // The box must comfortably contain 1000 m + 100 m hysteresis.
      expect(
        DistanceCalculator.isInBoundingBox(
          radar,
          latOffsetBy(baseLat, AppConstants.maxRadiusMeters + AppConstants.hysteresisMeters),
          baseLng,
        ),
        isTrue,
      );
      expect(
        DistanceCalculator.isInBoundingBox(radar, latOffsetBy(baseLat, 20000), baseLng),
        isFalse,
      );
    });

    test('withinRadius honours its predicate', () {
      final List<Radar> radars = <Radar>[
        radarAt(id: '001', lat: baseLat, lng: baseLng),
        radarAt(
          id: '002',
          lat: latOffsetBy(baseLat, 50),
          lng: baseLng,
          type: RadarType.intersectionEnforcement,
        ),
      ];

      final List<RadarDistance> matches = DistanceCalculator.withinRadius(
        radars: radars,
        latitude: baseLat,
        longitude: baseLng,
        radiusMeters: radius,
        where: (Radar r) => r.type == RadarType.intersectionEnforcement,
      );

      expect(matches, hasLength(1));
      expect(matches.single.radar.id, '002');
    });
  });
}
