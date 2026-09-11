import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'providers/filter_provider.dart';
import 'providers/location_provider.dart';
import 'providers/proximity_provider.dart';
import 'providers/radar_provider.dart';
import 'providers/settings_provider.dart';
import 'services/alarm_service.dart';
import 'services/background_service.dart';
import 'services/firestore_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase reads its config from google-services.json / GoogleService-Info
  // .plist. If those are missing the app still runs from the bundled dataset.
  bool firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (error) {
    developer.log(
      'Firebase nije dostupan — nastavlja se sa lokalnom kopijom.',
      name: 'main',
      error: error,
    );
  }

  final SharedPreferences preferences = await SharedPreferences.getInstance();

  final AlarmService alarmService = AlarmService();
  await alarmService.initialize();
  await configureBackgroundService();

  runApp(
    MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AlarmService>.value(value: alarmService),
        ChangeNotifierProvider<SettingsProvider>(
          create: (_) => SettingsProvider(preferences),
        ),
        ChangeNotifierProvider<RadarProvider>(
          create: (_) => RadarProvider(
            firestore: FirestoreService(enabled: firebaseReady),
          ),
        ),
        ChangeNotifierProvider<LocationProvider>(
          create: (_) => LocationProvider(),
        ),
        ChangeNotifierProvider<FilterProvider>(create: (_) => FilterProvider()),
        ChangeNotifierProxyProvider3<RadarProvider, SettingsProvider,
            LocationProvider, ProximityProvider>(
          create: (_) => ProximityProvider(alarmService: alarmService),
          update: (
            _,
            RadarProvider radars,
            SettingsProvider settings,
            LocationProvider location,
            ProximityProvider? previous,
          ) =>
              (previous ?? ProximityProvider(alarmService: alarmService))
                ..update(
                  radars: radars.radars,
                  zones: radars.speedZones,
                  settings: settings.settings,
                  position: location.position,
                ),
        ),
      ],
      child: const RadarMeApp(),
    ),
  );
}
