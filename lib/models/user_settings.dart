import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import 'radar.dart';

/// Everything the driver can configure. Immutable — [SettingsProvider] swaps in
/// a new instance on every change so widgets rebuild predictably.
///
/// The background isolate reads the same keys through [fromPreferences], which
/// keeps foreground and background alarms in sync.
class UserSettings {
  const UserSettings({
    required this.alertRadiusMeters,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.notificationsEnabled,
    required this.alarmSoundId,
    required this.themeMode,
    required this.showRadiusCircles,
    required this.mapZoom,
    required this.alertOnIntersection,
    required this.alertOnRoadEnforcement,
    required this.alertOnSpeedZone,
    required this.backgroundTrackingEnabled,
    required this.urbanSpeedLimitKmh,
    required this.ruralSpeedLimitKmh,
  });

  final double alertRadiusMeters;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool notificationsEnabled;
  final String alarmSoundId;
  final ThemeMode themeMode;
  final bool showRadiusCircles;
  final double mapZoom;
  final bool alertOnIntersection;
  final bool alertOnRoadEnforcement;
  final bool alertOnSpeedZone;
  final bool backgroundTrackingEnabled;
  final double urbanSpeedLimitKmh;
  final double ruralSpeedLimitKmh;

  static const UserSettings defaults = UserSettings(
    alertRadiusMeters: AppConstants.defaultRadiusMeters,
    soundEnabled: true,
    vibrationEnabled: true,
    notificationsEnabled: true,
    alarmSoundId: 'classic',
    themeMode: ThemeMode.system,
    showRadiusCircles: true,
    mapZoom: AppConstants.defaultZoom,
    alertOnIntersection: true,
    alertOnRoadEnforcement: true,
    alertOnSpeedZone: true,
    backgroundTrackingEnabled: false,
    urbanSpeedLimitKmh: AppConstants.defaultUrbanSpeedLimitKmh,
    ruralSpeedLimitKmh: AppConstants.defaultRuralSpeedLimitKmh,
  );

  AlarmSound get alarmSound => AlarmSound.byId(alarmSoundId);

  /// Whether radars of [type] are allowed to raise an alarm.
  bool alertsFor(RadarType type) => switch (type) {
        RadarType.intersectionEnforcement => alertOnIntersection,
        RadarType.roadEnforcementPoint => alertOnRoadEnforcement,
        RadarType.averageSpeedControlA ||
        RadarType.averageSpeedControlB =>
          alertOnSpeedZone,
      };

  double speedLimitFor(SpeedZone zone) =>
      zone.isUrban ? urbanSpeedLimitKmh : ruralSpeedLimitKmh;

  UserSettings copyWith({
    double? alertRadiusMeters,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? notificationsEnabled,
    String? alarmSoundId,
    ThemeMode? themeMode,
    bool? showRadiusCircles,
    double? mapZoom,
    bool? alertOnIntersection,
    bool? alertOnRoadEnforcement,
    bool? alertOnSpeedZone,
    bool? backgroundTrackingEnabled,
    double? urbanSpeedLimitKmh,
    double? ruralSpeedLimitKmh,
  }) =>
      UserSettings(
        alertRadiusMeters: alertRadiusMeters ?? this.alertRadiusMeters,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        alarmSoundId: alarmSoundId ?? this.alarmSoundId,
        themeMode: themeMode ?? this.themeMode,
        showRadiusCircles: showRadiusCircles ?? this.showRadiusCircles,
        mapZoom: mapZoom ?? this.mapZoom,
        alertOnIntersection: alertOnIntersection ?? this.alertOnIntersection,
        alertOnRoadEnforcement:
            alertOnRoadEnforcement ?? this.alertOnRoadEnforcement,
        alertOnSpeedZone: alertOnSpeedZone ?? this.alertOnSpeedZone,
        backgroundTrackingEnabled:
            backgroundTrackingEnabled ?? this.backgroundTrackingEnabled,
        urbanSpeedLimitKmh: urbanSpeedLimitKmh ?? this.urbanSpeedLimitKmh,
        ruralSpeedLimitKmh: ruralSpeedLimitKmh ?? this.ruralSpeedLimitKmh,
      );

  factory UserSettings.fromPreferences(SharedPreferences prefs) => UserSettings(
        alertRadiusMeters:
            prefs.getDouble(_Keys.radius) ?? defaults.alertRadiusMeters,
        soundEnabled: prefs.getBool(_Keys.sound) ?? defaults.soundEnabled,
        vibrationEnabled:
            prefs.getBool(_Keys.vibration) ?? defaults.vibrationEnabled,
        notificationsEnabled:
            prefs.getBool(_Keys.notifications) ?? defaults.notificationsEnabled,
        alarmSoundId: prefs.getString(_Keys.alarmSound) ?? defaults.alarmSoundId,
        themeMode: _themeFromName(prefs.getString(_Keys.themeMode)),
        showRadiusCircles:
            prefs.getBool(_Keys.showCircles) ?? defaults.showRadiusCircles,
        mapZoom: prefs.getDouble(_Keys.mapZoom) ?? defaults.mapZoom,
        alertOnIntersection: prefs.getBool(_Keys.alertIntersection) ??
            defaults.alertOnIntersection,
        alertOnRoadEnforcement:
            prefs.getBool(_Keys.alertRoad) ?? defaults.alertOnRoadEnforcement,
        alertOnSpeedZone:
            prefs.getBool(_Keys.alertSpeedZone) ?? defaults.alertOnSpeedZone,
        backgroundTrackingEnabled: prefs.getBool(_Keys.backgroundTracking) ??
            defaults.backgroundTrackingEnabled,
        urbanSpeedLimitKmh:
            prefs.getDouble(_Keys.urbanLimit) ?? defaults.urbanSpeedLimitKmh,
        ruralSpeedLimitKmh:
            prefs.getDouble(_Keys.ruralLimit) ?? defaults.ruralSpeedLimitKmh,
      );

  Future<void> persist(SharedPreferences prefs) async {
    await Future.wait(<Future<bool>>[
      prefs.setDouble(_Keys.radius, alertRadiusMeters),
      prefs.setBool(_Keys.sound, soundEnabled),
      prefs.setBool(_Keys.vibration, vibrationEnabled),
      prefs.setBool(_Keys.notifications, notificationsEnabled),
      prefs.setString(_Keys.alarmSound, alarmSoundId),
      prefs.setString(_Keys.themeMode, themeMode.name),
      prefs.setBool(_Keys.showCircles, showRadiusCircles),
      prefs.setDouble(_Keys.mapZoom, mapZoom),
      prefs.setBool(_Keys.alertIntersection, alertOnIntersection),
      prefs.setBool(_Keys.alertRoad, alertOnRoadEnforcement),
      prefs.setBool(_Keys.alertSpeedZone, alertOnSpeedZone),
      prefs.setBool(_Keys.backgroundTracking, backgroundTrackingEnabled),
      prefs.setDouble(_Keys.urbanLimit, urbanSpeedLimitKmh),
      prefs.setDouble(_Keys.ruralLimit, ruralSpeedLimitKmh),
    ]);
  }

  static ThemeMode _themeFromName(String? name) => ThemeMode.values.firstWhere(
        (ThemeMode mode) => mode.name == name,
        orElse: () => ThemeMode.system,
      );
}

class _Keys {
  const _Keys._();

  static const String radius = 'settings.alert_radius_meters';
  static const String sound = 'settings.sound_enabled';
  static const String vibration = 'settings.vibration_enabled';
  static const String notifications = 'settings.notifications_enabled';
  static const String alarmSound = 'settings.alarm_sound_id';
  static const String themeMode = 'settings.theme_mode';
  static const String showCircles = 'settings.show_radius_circles';
  static const String mapZoom = 'settings.map_zoom';
  static const String alertIntersection = 'settings.alert_intersection';
  static const String alertRoad = 'settings.alert_road_enforcement';
  static const String alertSpeedZone = 'settings.alert_speed_zone';
  static const String backgroundTracking = 'settings.background_tracking';
  static const String urbanLimit = 'settings.urban_speed_limit';
  static const String ruralLimit = 'settings.rural_speed_limit';
}
