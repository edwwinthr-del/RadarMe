import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

/// Owns the GPS stream and the runtime permission state.
class LocationProvider extends ChangeNotifier {
  LocationProvider({LocationService service = const LocationService()})
      : _service = service;

  final LocationService _service;

  StreamSubscription<Position>? _subscription;
  Position? _position;
  LocationPermissionState _permission = LocationPermissionState.unknown;
  bool _isTracking = false;

  Position? get position => _position;
  LocationPermissionState get permission => _permission;
  bool get hasPermission => _permission.isUsable;
  bool get isTracking => _isTracking;

  double? get latitude => _position?.latitude;
  double? get longitude => _position?.longitude;

  /// Requests permission and, if granted, starts streaming. Safe to call again.
  Future<LocationPermissionState> initialize() async {
    _permission = await _service.ensurePermission();
    notifyListeners();

    if (_permission.isUsable) {
      _position ??= await _service.currentPosition();
      start();
      notifyListeners();
    }
    return _permission;
  }

  /// Upgrade to "Always", needed before background tracking is useful.
  Future<bool> requestBackgroundPermission() async {
    final bool granted = await _service.requestBackgroundPermission();
    if (granted) {
      _permission = LocationPermissionState.always;
      notifyListeners();
    }
    return granted;
  }

  /// Android only; a no-op that reports success on other platforms.
  Future<bool> requestIgnoreBatteryOptimizations() =>
      _service.requestIgnoreBatteryOptimizations();

  Future<bool> openSettings() => _service.openAppSettings();

  Future<bool> openLocationSettings() => _service.openLocationSettings();

  void start() {
    if (_isTracking || !_permission.isUsable) return;
    _isTracking = true;
    _subscription = _service.positionStream().listen(
      _onPosition,
      onError: (Object error) {
        developer.log(
          'GPS stream prekinut.',
          name: 'LocationProvider',
          error: error,
        );
        stop();
      },
      cancelOnError: false,
    );
  }

  void stop() {
    _subscription?.cancel();
    _subscription = null;
    if (_isTracking) {
      _isTracking = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    final Position? position = await _service.currentPosition();
    if (position != null) _onPosition(position);
  }

  void _onPosition(Position position) {
    _position = position;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
