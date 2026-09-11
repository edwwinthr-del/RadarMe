import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';

import '../models/radar.dart';
import '../models/user_settings.dart';
import '../services/alarm_service.dart';
import '../services/background_service.dart';
import '../services/proximity_engine.dart';
import '../services/speed_zone_tracker.dart';
import '../utils/distance_calculator.dart';

/// Turns GPS fixes into alarms, the map banner and the corridor readout.
///
/// Also arbitrates with the background isolate: while this provider is on
/// screen it owns the alarms and keeps the service quiet; once the app is
/// hidden it hands over and mirrors the snapshots the service sends back, so
/// the UI is already current when the driver returns.
class ProximityProvider extends ChangeNotifier with WidgetsBindingObserver {
  ProximityProvider({required AlarmService alarmService})
      : _alarm = alarmService {
    WidgetsBinding.instance.addObserver(this);
    _serviceUpdates =
        BackgroundServiceController.proximityUpdates().listen(_onServiceUpdate);
    _announceVisibility(true);
  }

  final AlarmService _alarm;
  final ProximityEngine _engine = ProximityEngine();
  final SpeedZoneTracker _zoneTracker = SpeedZoneTracker();

  StreamSubscription<Map<String, dynamic>?>? _serviceUpdates;
  Timer? _visibilityHeartbeat;
  bool _uiVisible = true;
  bool _disposed = false;

  List<Radar> _radars = const <Radar>[];
  List<SpeedZone> _zones = const <SpeedZone>[];
  UserSettings _settings = UserSettings.defaults;

  List<RadarDistance> _inRange = const <RadarDistance>[];
  RadarDistance? _nearest;
  RadarDistance? _activeAlarm;
  bool _dismissed = false;

  Position? _lastPosition;
  Position? _pendingPosition;
  bool _evaluationScheduled = false;

  List<RadarDistance> get inRange => _inRange;
  RadarDistance? get nearest => _nearest;
  RadarDistance? get activeAlarm => _activeAlarm;
  bool get showAlarmBanner => _activeAlarm != null && !_dismissed;
  SpeedZoneSession? get session => _zoneTracker.session;

  /// Fed by `ChangeNotifierProxyProvider` whenever radars, settings or the
  /// position change.
  void update({
    required List<Radar> radars,
    required List<SpeedZone> zones,
    required UserSettings settings,
    Position? position,
  }) {
    final bool radarsChanged = !identical(_radars, radars);
    final bool alertingChanged = _alertingDiffers(settings);

    _radars = radars;
    _zones = zones;
    _settings = settings;

    if (radarsChanged || alertingChanged) _engine.reset();
    if (position == null) return;

    final bool positionChanged = !identical(position, _lastPosition);
    if (positionChanged || radarsChanged || alertingChanged) {
      _lastPosition = position;
      _schedule(position);
    }
  }

  void dismissAlarm() {
    if (_activeAlarm == null || _dismissed) return;
    _dismissed = true;
    unawaited(_alarm.stop());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // `inactive` still means the UI isolate is alive and processing fixes —
    // e.g. the notification shade is open — so it keeps owning the alarms.
    final bool visible = state == AppLifecycleState.resumed ||
        state == AppLifecycleState.inactive;
    if (visible == _uiVisible) return;
    _uiVisible = visible;
    _announceVisibility(visible);

    // Catch up immediately rather than waiting for the next fix.
    final Position? last = _lastPosition;
    if (visible && last != null) _evaluate(last);
  }

  void _announceVisibility(bool visible) {
    _visibilityHeartbeat?.cancel();
    unawaited(BackgroundServiceController.setUiVisible(visible));
    if (!visible) return;
    // Re-assert ownership periodically; if this provider dies without sending
    // `false`, the service resumes alarming once the pings stop.
    _visibilityHeartbeat = Timer.periodic(
      const Duration(seconds: 30),
      (_) => unawaited(BackgroundServiceController.setUiVisible(true)),
    );
  }

  /// While hidden, the service is the alarm authority; reflect what it saw so
  /// the map and the nearest-radar readout are correct on resume.
  void _onServiceUpdate(Map<String, dynamic>? event) {
    if (_disposed || _uiVisible || event == null || _radars.isEmpty) return;

    final String? nearestId = event['nearestId'] as String?;
    final double? nearestMeters = (event['nearestMeters'] as num?)?.toDouble();
    if (nearestId == null || nearestMeters == null) return;

    for (final Radar radar in _radars) {
      if (radar.id != nearestId) continue;
      _nearest = RadarDistance(radar, nearestMeters);
      notifyListeners();
      return;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _visibilityHeartbeat?.cancel();
    _serviceUpdates?.cancel();
    super.dispose();
  }

  bool _alertingDiffers(UserSettings next) =>
      next.alertRadiusMeters != _settings.alertRadiusMeters ||
      next.alertOnIntersection != _settings.alertOnIntersection ||
      next.alertOnRoadEnforcement != _settings.alertOnRoadEnforcement ||
      next.alertOnSpeedZone != _settings.alertOnSpeedZone;

  /// `update` runs inside the widget build phase, so the actual work — and the
  /// `notifyListeners` it ends with — is deferred to a microtask.
  void _schedule(Position position) {
    _pendingPosition = position;
    if (_evaluationScheduled) return;
    _evaluationScheduled = true;
    scheduleMicrotask(() {
      _evaluationScheduled = false;
      final Position? pending = _pendingPosition;
      _pendingPosition = null;
      if (pending != null) _evaluate(pending);
    });
  }

  void _evaluate(Position position) {
    if (_disposed) return;
    final ProximityResult result = _engine.evaluate(
      radars: _radars,
      latitude: position.latitude,
      longitude: position.longitude,
      radiusMeters: _settings.alertRadiusMeters,
      isAlertable: (Radar radar) => _settings.alertsFor(radar.type),
    );

    _inRange = result.inRange;
    _nearest = result.nearest;

    for (final RadarDistance alert in result.newAlerts) {
      unawaited(
        _alarm.triggerRadarAlarm(
          radar: alert.radar,
          meters: alert.meters,
          settings: _settings,
        ),
      );
    }

    if (result.newAlerts.isNotEmpty) {
      _activeAlarm = result.newAlerts.first;
      _dismissed = false;
    } else if (_inRange.isEmpty) {
      _activeAlarm = null;
      _dismissed = false;
    } else if (_activeAlarm != null) {
      // Keep the banner on the same radar, but refresh its distance.
      final String id = _activeAlarm!.radar.id;
      _activeAlarm = _inRange.firstWhere(
        (RadarDistance item) => item.radar.id == id,
        orElse: () => _inRange.first,
      );
    }

    _trackSpeedZone(position);
    notifyListeners();
  }

  void _trackSpeedZone(Position position) {
    final SpeedZoneCompletion? completion = _zoneTracker.update(
      zones: _zones,
      position: position,
      settings: _settings,
    );
    if (completion == null || !completion.isOverLimit) return;

    unawaited(
      _alarm.triggerSpeedZoneAlarm(
        zone: completion.zone,
        averageKmh: completion.averageKmh,
        limitKmh: completion.limitKmh,
        settings: _settings,
      ),
    );
  }
}
