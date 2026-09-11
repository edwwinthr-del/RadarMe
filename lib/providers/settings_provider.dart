import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/radar.dart';
import '../models/user_settings.dart';
import '../services/background_service.dart';

/// Persists [UserSettings] and keeps the background isolate in step.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._preferences)
      : _settings = UserSettings.fromPreferences(_preferences);

  final SharedPreferences _preferences;
  UserSettings _settings;

  UserSettings get settings => _settings;
  ThemeMode get themeMode => _settings.themeMode;

  Future<void> _save(UserSettings next) async {
    _settings = next;
    notifyListeners();
    await next.persist(_preferences);
    await BackgroundServiceController.notifySettingsChanged();
  }

  Future<void> setAlertRadius(double meters) =>
      _save(_settings.copyWith(alertRadiusMeters: meters));

  Future<void> setSoundEnabled(bool value) =>
      _save(_settings.copyWith(soundEnabled: value));

  Future<void> setVibrationEnabled(bool value) =>
      _save(_settings.copyWith(vibrationEnabled: value));

  Future<void> setNotificationsEnabled(bool value) =>
      _save(_settings.copyWith(notificationsEnabled: value));

  Future<void> setAlarmSound(String id) =>
      _save(_settings.copyWith(alarmSoundId: id));

  Future<void> setThemeMode(ThemeMode mode) =>
      _save(_settings.copyWith(themeMode: mode));

  Future<void> setShowRadiusCircles(bool value) =>
      _save(_settings.copyWith(showRadiusCircles: value));

  Future<void> setMapZoom(double zoom) =>
      _save(_settings.copyWith(mapZoom: zoom));

  Future<void> setUrbanSpeedLimit(double kmh) =>
      _save(_settings.copyWith(urbanSpeedLimitKmh: kmh));

  Future<void> setRuralSpeedLimit(double kmh) =>
      _save(_settings.copyWith(ruralSpeedLimitKmh: kmh));

  /// Toggles whether radars of [type] may raise an alarm.
  Future<void> setAlertForType(RadarType type, bool value) => switch (type) {
        RadarType.intersectionEnforcement =>
          _save(_settings.copyWith(alertOnIntersection: value)),
        RadarType.roadEnforcementPoint =>
          _save(_settings.copyWith(alertOnRoadEnforcement: value)),
        RadarType.averageSpeedControlA ||
        RadarType.averageSpeedControlB =>
          _save(_settings.copyWith(alertOnSpeedZone: value)),
      };

  /// Starts or stops the foreground service alongside persisting the flag.
  Future<void> setBackgroundTracking(bool value) async {
    await _save(_settings.copyWith(backgroundTrackingEnabled: value));
    if (value) {
      await BackgroundServiceController.start();
    } else {
      await BackgroundServiceController.stop();
    }
  }

  /// Brings the running service in line with the stored preference at startup.
  Future<void> syncBackgroundService() async {
    final bool running = await BackgroundServiceController.isRunning();
    if (_settings.backgroundTrackingEnabled && !running) {
      await BackgroundServiceController.start();
    } else if (!_settings.backgroundTrackingEnabled && running) {
      await BackgroundServiceController.stop();
    }
  }
}
