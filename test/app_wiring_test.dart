import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radarme/config/constants.dart';
import 'package:radarme/config/routes.dart';

import 'test_helpers.dart';

void main() {
  group('AppRoutes', () {
    Route<dynamic>? route(String name, [Object? arguments]) =>
        AppRoutes.onGenerateRoute(
          RouteSettings(name: name, arguments: arguments),
        );

    test('every declared route resolves', () {
      expect(route(AppRoutes.splash), isNotNull);
      expect(route(AppRoutes.home), isNotNull);
      expect(
        route(AppRoutes.radarDetail, radarAt(id: '001', lat: 42.4, lng: 19.2)),
        isNotNull,
      );
    });

    test('unknown names and bad arguments resolve to nothing', () {
      // The detail route carries its radar as an argument; anything else would
      // otherwise blow up inside the builder rather than at navigation time.
      expect(route('/nema-ovoga'), isNull);
      expect(route(AppRoutes.radarDetail), isNull);
      expect(route(AppRoutes.radarDetail, 'nije radar'), isNull);
    });
  });

  group('bundled assets', () {
    test('every alarm tone declared in settings exists on disk', () {
      for (final AlarmSound sound in AlarmSound.all) {
        expect(
          File('assets/${sound.asset}').existsSync(),
          isTrue,
          reason: '${sound.id} points at a missing file',
        );
      }
    });

    test('the radar dataset is where the constants say it is', () {
      expect(File(AppConstants.localRadarsAsset).existsSync(), isTrue);
    });

    test('byId falls back to the classic tone for an unknown id', () {
      expect(AlarmSound.byId('nema-ga').id, AlarmSound.classic.id);
    });
  });
}
