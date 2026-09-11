import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../config/constants.dart';
import '../models/radar.dart';
import '../services/firestore_service.dart';

/// Where the radar list currently in memory came from.
enum RadarDataSource { none, firestore, bundled }

/// Owns the radar dataset: Firestore first, bundled JSON as the fallback.
class RadarProvider extends ChangeNotifier {
  RadarProvider({required FirestoreService firestore}) : _firestore = firestore;

  final FirestoreService _firestore;

  List<Radar> _radars = const <Radar>[];
  List<SpeedZone> _speedZones = const <SpeedZone>[];
  List<String> _cities = const <String>[];
  bool _isLoading = false;
  RadarDataSource _source = RadarDataSource.none;
  String? _warning;
  double? _remoteDefaultRadius;

  List<Radar> get radars => _radars;
  List<SpeedZone> get speedZones => _speedZones;
  List<String> get cities => _cities;
  bool get isLoading => _isLoading;
  bool get isReady => _radars.isNotEmpty;
  RadarDataSource get source => _source;

  /// Set when Firestore was unreachable and the bundled copy was used instead.
  String? get warning => _warning;

  /// `default_radius_meters` from `app_config/settings`, when available.
  double? get remoteDefaultRadius => _remoteDefaultRadius;

  Radar? byId(String? id) {
    if (id == null) return null;
    for (final Radar radar in _radars) {
      if (radar.id == id) return radar;
    }
    return null;
  }

  SpeedZone? zoneContaining(String radarId) {
    for (final SpeedZone zone in _speedZones) {
      if (zone.pointA.id == radarId || zone.pointB.id == radarId) return zone;
    }
    return null;
  }

  Future<void> load() async {
    _isLoading = true;
    _warning = null;
    notifyListeners();

    try {
      final List<Radar> remote = await _firestore.fetchRadars();
      _remoteDefaultRadius = await _firestore.fetchDefaultRadius();
      _apply(remote, RadarDataSource.firestore);
    } catch (error) {
      developer.log(
        'Firestore nedostupan, koristi se lokalna kopija.',
        name: 'RadarProvider',
        error: error,
      );
      try {
        _apply(
          Radar.decodeList(
            await rootBundle.loadString(AppConstants.localRadarsAsset),
          ),
          RadarDataSource.bundled,
        );
        _warning = 'Offline režim — podaci iz lokalne kopije.';
      } catch (fallbackError) {
        developer.log(
          'Lokalna kopija radara se ne može učitati.',
          name: 'RadarProvider',
          error: fallbackError,
        );
        _warning = 'Podaci o radarima nisu dostupni.';
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _apply(List<Radar> radars, RadarDataSource source) {
    _radars = radars;
    _source = source;
    _speedZones = SpeedZone.from(radars);
    _cities = (radars.map((Radar radar) => radar.city).toSet().toList()
      ..sort())
        .toList(growable: false);
  }
}
