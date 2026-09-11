import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Configuration values shared across the whole app.
class AppConstants {
  const AppConstants._();

  static const String appName = 'RadarME';
  static const String appVersion = '1.0.0';
  static const String dataSource = 'SAT-TRAKT V8';
  static const String tileUserAgent = 'me.radarme.app';

  // --- Data sources -------------------------------------------------------
  static const String radarsCollection = 'radars';
  static const String appConfigCollection = 'app_config';
  static const String appConfigDocumentId = 'settings';
  static const String localRadarsAsset = 'assets/data/radars.json';

  // --- Proximity ----------------------------------------------------------
  static const double defaultRadiusMeters = 300;
  static const double minRadiusMeters = 100;
  static const double maxRadiusMeters = 1000;
  static const int radiusSliderDivisions = 18; // 100 → 1000 in 50 m steps

  /// Extra distance a driver must put between themselves and an already
  /// announced radar before that radar may alarm again.
  static const double hysteresisMeters = 100;

  /// Only radars inside this lat/lng box around the driver get measured.
  /// At Montenegro's latitude (~42.5°N) one degree of latitude spans ~111 km
  /// and one degree of longitude ~82 km, so the box reaches ~5.5 km in every
  /// direction — comfortably beyond the 1 km maximum radius plus hysteresis.
  static const double boundingBoxLatDegrees = 0.05;
  static const double boundingBoxLngDegrees = 0.07;

  static const int positionDistanceFilterMeters = 10;

  // --- Average speed corridors -------------------------------------------
  static const double speedZoneTriggerMeters = 500;
  static const Duration speedZoneTimeout = Duration(hours: 1);
  static const double defaultUrbanSpeedLimitKmh = 50;
  static const double defaultRuralSpeedLimitKmh = 80;
  static const double minSpeedLimitKmh = 30;
  static const double maxSpeedLimitKmh = 130;

  /// Share of the limit above which the corridor readout turns amber.
  static const double speedZoneWarningFactor = 0.9;

  // --- Map ----------------------------------------------------------------
  static const LatLng montenegroCenter = LatLng(42.7087, 19.3744);
  static const double defaultZoom = 13;
  static const double minZoom = 7;
  static const double maxZoom = 18;
  static const double focusedZoom = 15;
  static const String tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // --- Notifications ------------------------------------------------------
  static const String alertChannelId = 'radarme_alerts';
  static const String alertChannelName = 'Upozorenja o radarima';
  static const String alertChannelDescription =
      'Obavještenja kada se približite radaru.';
  static const int alertNotificationId = 4201;

  static const String serviceChannelId = 'radarme_tracking';
  static const String serviceChannelName = 'Praćenje u pozadini';
  static const int serviceNotificationId = 4202;

  static const Duration splashMinimumDuration = Duration(milliseconds: 1500);
}

/// Brand and semantic colours. Radar type colours are deliberately identical in
/// both themes so a marker always means the same thing.
class AppColors {
  const AppColors._();

  static const Color intersection = Color(0xFFE53935);
  static const Color roadEnforcement = Color(0xFFFB8C00);
  static const Color averageSpeedA = Color(0xFF8E24AA);
  static const Color averageSpeedB = Color(0xFFAB47BC);

  static const Color lightPrimary = Color(0xFF1565C0);
  static const Color lightPrimaryVariant = Color(0xFF0D47A1);
  static const Color lightAccent = Color(0xFFFF6D00);
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTextPrimary = Color(0xFF212121);
  static const Color lightTextSecondary = Color(0xFF757575);
  static const Color lightError = Color(0xFFD32F2F);
  static const Color lightSuccess = Color(0xFF2E7D32);

  static const Color darkPrimary = Color(0xFF42A5F5);
  static const Color darkPrimaryVariant = Color(0xFF1E88E5);
  static const Color darkAccent = Color(0xFFFFB74D);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkTextPrimary = Color(0xFFE0E0E0);
  static const Color darkTextSecondary = Color(0xFF9E9E9E);
  static const Color darkError = Color(0xFFEF5350);
  static const Color darkSuccess = Color(0xFF66BB6A);

  static const Color userLocation = Color(0xFF1E88E5);

  /// Green / amber / red used by the corridor speed readout.
  static Color success(Brightness b) =>
      b == Brightness.dark ? darkSuccess : lightSuccess;
  static Color danger(Brightness b) =>
      b == Brightness.dark ? darkError : lightError;
  static const Color warning = Color(0xFFF9A825);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double button = 12;
  static const double sheet = 24;
  static const double chip = 40;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius buttonRadius =
      BorderRadius.all(Radius.circular(button));
  static const BorderRadius sheetRadius = BorderRadius.vertical(
    top: Radius.circular(sheet),
  );
}

/// The built-in alarm tones the user can pick between in settings.
class AlarmSound {
  const AlarmSound({
    required this.id,
    required this.label,
    required this.asset,
  });

  final String id;
  final String label;

  /// Path relative to `assets/`, which is the prefix `AssetSource` applies.
  final String asset;

  static const AlarmSound classic = AlarmSound(
    id: 'classic',
    label: 'Klasični',
    asset: 'sounds/alert_classic.wav',
  );
  static const AlarmSound urgent = AlarmSound(
    id: 'urgent',
    label: 'Hitni',
    asset: 'sounds/alert_urgent.wav',
  );
  static const AlarmSound soft = AlarmSound(
    id: 'soft',
    label: 'Blagi',
    asset: 'sounds/alert_soft.wav',
  );
  static const AlarmSound sonar = AlarmSound(
    id: 'radar',
    label: 'Radar',
    asset: 'sounds/alert_radar.wav',
  );

  static const List<AlarmSound> all = <AlarmSound>[classic, urgent, soft, sonar];

  static AlarmSound byId(String id) =>
      all.firstWhere((sound) => sound.id == id, orElse: () => classic);
}
