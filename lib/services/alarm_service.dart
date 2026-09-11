import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../models/user_settings.dart';
import '../utils/formatters.dart';

/// Produces the actual warning: tone, vibration and notification.
///
/// One instance lives on the UI isolate and another inside the background
/// isolate; neither shares state, so both are safe to construct independently.
class AlarmService {
  AlarmService();

  final AudioPlayer _player = AudioPlayer(playerId: 'radarme_alarm');
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  Future<void> initialize() async {
    if (_initialised) return;

    await _notifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: false,
          requestSoundPermission: true,
        ),
      ),
    );

    // The tone is played through audioplayers so it also sounds while the iOS
    // ringer switch is off; the notification itself therefore stays silent.
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            AppConstants.alertChannelId,
            AppConstants.alertChannelName,
            description: AppConstants.alertChannelDescription,
            importance: Importance.max,
            playSound: false,
            enableVibration: false,
          ),
        );

    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.setAudioContext(
      AudioContext(
        android: const AudioContextAndroid(
          isSpeakerphoneOn: false,
          stayAwake: true,
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: <AVAudioSessionOptions>{AVAudioSessionOptions.duckOthers},
        ),
      ),
    );

    _initialised = true;
  }

  Future<void> triggerRadarAlarm({
    required Radar radar,
    required double meters,
    required UserSettings settings,
  }) =>
      _fire(
        title: '${radar.type.label} • ${Formatters.distance(meters)}',
        body: '${radar.name} (${Formatters.city(radar.city)})',
        settings: settings,
      );

  Future<void> triggerSpeedZoneAlarm({
    required SpeedZone zone,
    required double averageKmh,
    required double limitKmh,
    required UserSettings settings,
  }) =>
      _fire(
        title: 'Prosječna brzina ${Formatters.speed(averageKmh)}',
        body: 'Ograničenje ${Formatters.speed(limitKmh)} — ${zone.name}',
        settings: settings,
      );

  Future<void> _fire({
    required String title,
    required String body,
    required UserSettings settings,
  }) async {
    await initialize();

    if (settings.soundEnabled) {
      await playSound(settings.alarmSoundId);
    }
    if (settings.vibrationEnabled && await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: <int>[0, 400, 180, 400]);
    }
    if (settings.notificationsEnabled) {
      await _notify(title: title, body: body);
    }
  }

  /// Also used by the settings screen's preview button.
  Future<void> playSound(String soundId) async {
    await initialize();
    await _player.stop();
    await _player.play(AssetSource(AlarmSound.byId(soundId).asset));
  }

  Future<void> _notify({required String title, required String body}) =>
      _notifications.show(
        AppConstants.alertNotificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            AppConstants.alertChannelId,
            AppConstants.alertChannelName,
            channelDescription: AppConstants.alertChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.navigation,
            visibility: NotificationVisibility.public,
            playSound: false,
            enableVibration: false,
            autoCancel: true,
            color: AppColors.lightPrimary,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: false,
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),
      );

  Future<void> requestNotificationPermission() async {
    await initialize();
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, sound: true);
  }

  /// Silences the current tone without stopping proximity tracking.
  Future<void> stop() async {
    await _player.stop();
    await Vibration.cancel();
  }

  Future<void> dispose() => _player.dispose();
}
