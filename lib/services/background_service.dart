import 'dart:async';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../models/user_settings.dart';
import '../utils/distance_calculator.dart';
import '../utils/formatters.dart';
import 'alarm_service.dart';
import 'location_service.dart';
import 'proximity_engine.dart';

/// Isolate → UI: a fresh proximity snapshot.
const String kProximityEvent = 'proximity';

/// UI → isolate: settings were edited, reload them.
const String kSettingsChangedEvent = 'settingsChanged';

/// UI → isolate: shut down.
const String kStopServiceEvent = 'stopService';

/// UI → isolate: the app is (or is no longer) on screen. While it is, the UI
/// isolate owns the alarms and the service stays quiet, so the driver never
/// hears the same radar announced twice.
const String kVisibilityEvent = 'uiVisibility';

/// How long a visibility ping keeps the service quiet. The UI re-sends one
/// every 30 s, so if it dies without saying goodbye the service starts
/// alarming again on its own — failing towards warning the driver, not silence.
const Duration kVisibilityTimeout = Duration(seconds: 60);

/// Registers the background isolate. Called once from `main()`; the service is
/// only actually started when the driver enables background tracking.
Future<void> configureBackgroundService() async {
  // Android 8+ refuses to promote a service to the foreground without an
  // existing channel, so create it before the service can ever start.
  await FlutterLocalNotificationsPlugin()
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(
        const AndroidNotificationChannel(
          AppConstants.serviceChannelId,
          AppConstants.serviceChannelName,
          description: 'Obavještenje dok RadarME prati lokaciju u pozadini.',
          importance: Importance.low,
        ),
      );

  await FlutterBackgroundService().configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onBackgroundServiceStart,
      autoStart: false,
      autoStartOnBoot: false,
      isForegroundMode: true,
      notificationChannelId: AppConstants.serviceChannelId,
      initialNotificationTitle: AppConstants.appName,
      initialNotificationContent: 'Praćenje radara je aktivno',
      foregroundServiceNotificationId: AppConstants.serviceNotificationId,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: onBackgroundServiceStart,
      onBackground: onIosBackground,
    ),
  );
}

/// Start/stop/notify helpers used by the settings screen and the providers.
class BackgroundServiceController {
  const BackgroundServiceController._();

  static Future<bool> isRunning() => FlutterBackgroundService().isRunning();

  static Future<bool> start() async {
    final FlutterBackgroundService service = FlutterBackgroundService();
    if (await service.isRunning()) return true;
    return service.startService();
  }

  static Future<void> stop() async {
    final FlutterBackgroundService service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke(kStopServiceEvent);
    }
  }

  /// Nudges the isolate to re-read shared_preferences.
  static Future<void> notifySettingsChanged() async {
    final FlutterBackgroundService service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke(kSettingsChangedEvent);
    }
  }

  /// Tells the service whether the UI is on screen and handling alarms itself.
  static Future<void> setUiVisible(bool visible) async {
    final FlutterBackgroundService service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke(kVisibilityEvent, <String, dynamic>{'visible': visible});
    }
  }

  static Stream<Map<String, dynamic>?> proximityUpdates() =>
      FlutterBackgroundService().on(kProximityEvent);
}

/// Entry point of the background isolate.
@pragma('vm:entry-point')
void onBackgroundServiceStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
  }

  final AlarmService alarm = AlarmService();
  await alarm.initialize();

  final SharedPreferences preferences = await SharedPreferences.getInstance();
  UserSettings settings = UserSettings.fromPreferences(preferences);

  // The isolate always reads the bundled copy: it must work with no network and
  // without waiting on Firestore.
  final List<Radar> radars = Radar.decodeList(
    await rootBundle.loadString(AppConstants.localRadarsAsset),
  );
  final ProximityEngine engine = ProximityEngine();

  StreamSubscription<Position>? positions;

  /// When the UI last reported itself visible; `null` means it is not.
  DateTime? uiSeenAt;
  bool uiOwnsAlarms() =>
      uiSeenAt != null &&
      DateTime.now().difference(uiSeenAt!) < kVisibilityTimeout;

  service.on(kVisibilityEvent).listen((Map<String, dynamic>? event) {
    uiSeenAt = (event?['visible'] as bool? ?? false) ? DateTime.now() : null;
  });

  service.on(kSettingsChangedEvent).listen((Map<String, dynamic>? _) async {
    await preferences.reload();
    settings = UserSettings.fromPreferences(preferences);
    // Radius or filter changes invalidate what was already announced.
    engine.reset();
  });

  service.on(kStopServiceEvent).listen((Map<String, dynamic>? _) async {
    await positions?.cancel();
    await alarm.stop();
    await service.stopSelf();
  });

  positions = const LocationService()
      .positionStream(background: true)
      .listen((Position position) async {
    final ProximityResult result = engine.evaluate(
      radars: radars,
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: settings.alertRadiusMeters,
      isAlertable: (Radar radar) => settings.alertsFor(radar.type),
    );

    if (!uiOwnsAlarms()) {
      for (final RadarDistance alert in result.newAlerts) {
        await alarm.triggerRadarAlarm(
          radar: alert.radar,
          meters: alert.meters,
          settings: settings,
        );
      }
    }

    if (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      final String summary = result.nearest == null
          ? 'Praćenje radara je aktivno'
          : 'Najbliži radar: '
              '${Formatters.distance(result.nearest!.meters)} • '
              '${Formatters.city(result.nearest!.radar.city)}';
      await service.setForegroundNotificationInfo(
        title: AppConstants.appName,
        content: summary,
      );
    }

    service.invoke(kProximityEvent, <String, dynamic>{
      'latitude': position.latitude,
      'longitude': position.longitude,
      'nearestId': result.nearest?.radar.id,
      'nearestMeters': result.nearest?.meters,
      'inRangeIds': result.inRange
          .map((RadarDistance item) => item.radar.id)
          .toList(growable: false),
    });
  });
}

/// iOS background fetch tick. Returning true keeps the service registered.
@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}
