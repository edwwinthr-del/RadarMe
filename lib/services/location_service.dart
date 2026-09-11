import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../config/constants.dart';

/// Outcome of the runtime permission flow, in the order the UI reacts to it.
enum LocationPermissionState {
  unknown,
  serviceDisabled,
  denied,
  deniedForever,
  whileInUse,
  always;

  bool get isUsable => this == whileInUse || this == always;
}

/// Thin wrapper over geolocator + permission_handler.
///
/// Used from the UI isolate and from the background isolate, so it holds no
/// state of its own.
class LocationService {
  const LocationService();

  /// Explains nothing on its own — the caller shows the rationale first, then
  /// calls this to perform the actual request.
  Future<LocationPermissionState> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationPermissionState.serviceDisabled;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return switch (permission) {
      LocationPermission.denied => LocationPermissionState.denied,
      LocationPermission.deniedForever => LocationPermissionState.deniedForever,
      LocationPermission.whileInUse => LocationPermissionState.whileInUse,
      LocationPermission.always => LocationPermissionState.always,
      LocationPermission.unableToDetermine => LocationPermissionState.unknown,
    };
  }

  /// Android 10+ / iOS "Always" upgrade, required for background alerts.
  Future<bool> requestBackgroundPermission() async {
    final ph.PermissionStatus status =
        await ph.Permission.locationAlways.request();
    return status.isGranted;
  }

  /// Android 13+ needs an explicit grant before notifications are shown.
  Future<bool> requestNotificationPermission() async {
    final ph.PermissionStatus status =
        await ph.Permission.notification.request();
    return status.isGranted;
  }

  /// Without this Android may doze the foreground service on aggressive OEMs.
  Future<bool> requestIgnoreBatteryOptimizations() async {
    if (!Platform.isAndroid) return true;
    final ph.PermissionStatus status =
        await ph.Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  Future<bool> openAppSettings() => ph.openAppSettings();

  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  /// A fix right now, falling back to the last cached one if the GPS is slow.
  Future<Position?> currentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 12));
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  /// A fix every [AppConstants.positionDistanceFilterMeters] of movement.
  ///
  /// Pass [background] from the background isolate so iOS keeps delivering
  /// updates and shows the blue status-bar indicator. On Android the foreground
  /// service is owned by `flutter_background_service`, so geolocator does not
  /// raise a second one.
  Stream<Position> positionStream({bool background = false}) =>
      Geolocator.getPositionStream(
        locationSettings: _settings(background: background),
      );

  LocationSettings _settings({required bool background}) {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: AppConstants.positionDistanceFilterMeters,
        intervalDuration: const Duration(seconds: 2),
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: AppConstants.positionDistanceFilterMeters,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: background,
        showBackgroundLocationIndicator: background,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: AppConstants.positionDistanceFilterMeters,
    );
  }
}
