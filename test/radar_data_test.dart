import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radarme/models/radar.dart';
import 'package:radarme/utils/capability_icons.dart';
import 'package:radarme/utils/formatters.dart';

void main() {
  // Tests run from the package root, so the bundled asset is readable directly.
  final List<Radar> radars =
      Radar.decodeList(File('assets/data/radars.json').readAsStringSync());

  group('bundled dataset', () {
    test('holds all 88 locations with contiguous ids', () {
      expect(radars, hasLength(88));
      for (int i = 0; i < radars.length; i++) {
        expect(radars[i].id, (i + 1).toString().padLeft(3, '0'));
      }
    });

    test('every coordinate falls inside Montenegro', () {
      for (final Radar radar in radars) {
        expect(radar.lat, inInclusiveRange(41.8, 43.6), reason: radar.id);
        expect(radar.lng, inInclusiveRange(18.4, 20.4), reason: radar.id);
      }
    });

    test('no two locations share a coordinate', () {
      final Set<String> seen = <String>{};
      for (final Radar radar in radars) {
        expect(seen.add('${radar.lat},${radar.lng}'), isTrue, reason: radar.id);
      }
    });

    test('no type or status string was silently defaulted', () {
      // fromWire falls back rather than throwing, so a typo in the JSON would
      // be masked by the model. Check the raw strings themselves.
      final List<dynamic> raw = jsonDecode(
        File('assets/data/radars.json').readAsStringSync(),
      ) as List<dynamic>;

      final Set<String> validTypes =
          RadarType.values.map((RadarType t) => t.wireName).toSet();
      final Set<String> validStatuses =
          RadarStatus.values.map((RadarStatus s) => s.wireName).toSet();

      expect(raw, hasLength(88));
      for (final dynamic entry in raw) {
        final Map<String, dynamic> record = Map<String, dynamic>.from(entry as Map);
        expect(validTypes, contains(record['type']), reason: '${record['id']}');
        expect(validStatuses, contains(record['status']), reason: '${record['id']}');
      }
    });

    test('every capability key has a label and icon', () {
      for (final Radar radar in radars) {
        for (final String key in radar.capabilities) {
          final CapabilityInfo info = CapabilityIcons.of(key);
          expect(
            info.label,
            isNot(key),
            reason: '$key is unmapped and would render as a raw key',
          );
        }
      }
    });

    test('capabilities are never duplicated within a location', () {
      for (final Radar radar in radars) {
        expect(
          radar.capabilities.toSet(),
          hasLength(radar.capabilities.length),
          reason: radar.id,
        );
      }
    });

    test('average-speed pairings are symmetric and correctly typed', () {
      final Map<String, Radar> byId = <String, Radar>{
        for (final Radar radar in radars) radar.id: radar,
      };

      for (final Radar radar in radars) {
        if (!radar.isAverageSpeed) {
          expect(radar.pairedWith, isNull, reason: radar.id);
          continue;
        }
        expect(radar.pairedWith, isNotNull, reason: radar.id);

        final Radar? partner = byId[radar.pairedWith];
        expect(partner, isNotNull, reason: radar.id);
        expect(partner!.pairedWith, radar.id, reason: 'asymmetric ${radar.id}');
        expect(partner.type, isNot(radar.type), reason: 'A must pair with B');
      }
    });

    test('SpeedZone.from builds 27 corridors, each A→B', () {
      final List<SpeedZone> zones = SpeedZone.from(radars);
      expect(zones, hasLength(27));
      for (final SpeedZone zone in zones) {
        expect(zone.pointA.type, RadarType.averageSpeedControlA);
        expect(zone.pointB.type, RadarType.averageSpeedControlB);
        // Sanity-check the geometry: real corridors are hundreds of metres to
        // a few kilometres long, never zero and never across the country.
        expect(zone.lengthMeters, greaterThan(100), reason: zone.id);
        expect(zone.lengthMeters, lessThan(10000), reason: zone.id);
      }
    });

    test('expected type and status distribution', () {
      int count(bool Function(Radar) test) => radars.where(test).length;

      expect(count((Radar r) => r.type == RadarType.intersectionEnforcement), 5);
      expect(count((Radar r) => r.type == RadarType.roadEnforcementPoint), 29);
      expect(count((Radar r) => r.type == RadarType.averageSpeedControlA), 27);
      expect(count((Radar r) => r.type == RadarType.averageSpeedControlB), 27);
      expect(count((Radar r) => r.isActive), 12);
      expect(radars.map((Radar r) => r.city).toSet(), hasLength(21));
    });

    test('every location carries a name, city and at least one capability', () {
      for (final Radar radar in radars) {
        expect(radar.name.trim(), isNotEmpty, reason: radar.id);
        expect(radar.city.trim(), isNotEmpty, reason: radar.id);
        expect(radar.capabilities, isNotEmpty, reason: radar.id);
      }
    });

    test('json round-trips without loss', () {
      for (final Radar radar in radars) {
        final Radar copy = Radar.fromJson(radar.toJson());
        expect(copy.id, radar.id);
        expect(copy.lat, radar.lat);
        expect(copy.lng, radar.lng);
        expect(copy.type, radar.type);
        expect(copy.status, radar.status);
        expect(copy.pairedWith, radar.pairedWith);
        expect(copy.capabilities, radar.capabilities);
        expect(copy.cameras.length, radar.cameras.length);
      }
    });
  });

  group('Formatters', () {
    test('distance switches units at sensible points', () {
      expect(Formatters.distance(240), '240 m');
      expect(Formatters.distance(999), '999 m');
      expect(Formatters.distance(1000), '1.0 km');
      expect(Formatters.distance(2400), '2.4 km');
      expect(Formatters.distance(18000), '18 km');
    });

    test('distance tolerates non-finite input', () {
      expect(Formatters.distance(double.nan), '—');
      expect(Formatters.distance(double.infinity), '—');
    });

    test('duration gains an hours field only when needed', () {
      expect(Formatters.duration(const Duration(minutes: 4, seconds: 7)), '4:07');
      expect(
        Formatters.duration(const Duration(hours: 1, minutes: 4, seconds: 7)),
        '1:04:07',
      );
    });

    test('city names are title-cased', () {
      expect(Formatters.city('PODGORICA'), 'Podgorica');
      expect(Formatters.city('BIJELO POLJE'), 'Bijelo Polje');
    });

    test('coordinates keep six decimals', () {
      expect(Formatters.coordinates(42.44375, 19.24581111), '42.443750, 19.245811');
    });
  });
}
