import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config/constants.dart';

/// Enforcement category of a location, as recorded in the SAT-TRAKT document.
enum RadarType {
  intersectionEnforcement(
    'INTERSECTION_ENFORCEMENT',
    'Raskrsnica',
    'Kontrola raskrsnice',
    AppColors.intersection,
    Icons.traffic,
  ),
  roadEnforcementPoint(
    'ROAD_ENFORCEMENT_POINT',
    'Putni radar',
    'Kontrolna tačka na putu',
    AppColors.roadEnforcement,
    Icons.speed,
  ),
  averageSpeedControlA(
    'AVERAGE_SPEED_CONTROL_A',
    'Prosječna A',
    'Prosječna brzina — ulaz (A)',
    AppColors.averageSpeedA,
    Icons.login,
  ),
  averageSpeedControlB(
    'AVERAGE_SPEED_CONTROL_B',
    'Prosječna B',
    'Prosječna brzina — izlaz (B)',
    AppColors.averageSpeedB,
    Icons.logout,
  );

  const RadarType(this.wireName, this.shortLabel, this.label, this.color, this.icon);

  /// Value stored in Firestore and in the bundled JSON.
  final String wireName;
  final String shortLabel;
  final String label;
  final Color color;
  final IconData icon;

  bool get isAverageSpeed =>
      this == averageSpeedControlA || this == averageSpeedControlB;

  static RadarType fromWire(String? value) => values.firstWhere(
        (RadarType type) => type.wireName == value,
        orElse: () => roadEnforcementPoint,
      );
}

/// Whether the location is built and running, or still only planned.
enum RadarStatus {
  completed('COMPLETED', 'Aktivan'),
  pending('PENDING', 'Planiran');

  const RadarStatus(this.wireName, this.label);

  final String wireName;
  final String label;

  static RadarStatus fromWire(String? value) => values.firstWhere(
        (RadarStatus status) => status.wireName == value,
        orElse: () => pending,
      );
}

/// One physical camera installed at a location.
class CameraUnit {
  const CameraUnit({required this.model, this.lanes});

  final String model;

  /// Number of lanes the camera covers; `null` when the document leaves it out.
  final int? lanes;

  factory CameraUnit.fromJson(Map<String, dynamic> json) => CameraUnit(
        model: json['model'] as String? ?? '',
        lanes: (json['lanes'] as num?)?.toInt(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'model': model,
        'lanes': lanes,
      };
}

/// A single enforcement location.
class Radar {
  const Radar({
    required this.id,
    required this.name,
    required this.city,
    required this.type,
    required this.status,
    required this.lat,
    required this.lng,
    required this.capabilities,
    required this.cameras,
    this.pairedWith,
  });

  final String id;
  final String name;
  final String city;
  final RadarType type;
  final RadarStatus status;
  final double lat;
  final double lng;
  final List<String> capabilities;
  final List<CameraUnit> cameras;

  /// Id of the partner point for average-speed corridors.
  final String? pairedWith;

  LatLng get position => LatLng(lat, lng);

  bool get isAverageSpeed => type.isAverageSpeed;

  bool get isActive => status == RadarStatus.completed;

  factory Radar.fromJson(Map<String, dynamic> json) => Radar(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        city: json['city'] as String? ?? '',
        type: RadarType.fromWire(json['type'] as String?),
        status: RadarStatus.fromWire(json['status'] as String?),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        capabilities: (json['capabilities'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => e as String)
            .toList(growable: false),
        cameras: (json['cameras'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) =>
                CameraUnit.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(growable: false),
        pairedWith: json['pairedWith'] as String?,
      );

  factory Radar.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return Radar.fromJson(<String, dynamic>{...data, 'id': data['id'] ?? doc.id});
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'city': city,
        'type': type.wireName,
        'status': status.wireName,
        'lat': lat,
        'lng': lng,
        'capabilities': capabilities,
        'cameras': cameras.map((CameraUnit c) => c.toJson()).toList(),
        'pairedWith': pairedWith,
      };

  /// Decodes the `radars.json` payload, whether it came from the bundled asset
  /// or from anywhere else.
  static List<Radar> decodeList(String source) {
    final List<dynamic> decoded = jsonDecode(source) as List<dynamic>;
    return decoded
        .map((dynamic entry) =>
            Radar.fromJson(Map<String, dynamic>.from(entry as Map)))
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Radar && other.id == id);

  @override
  int get hashCode => id.hashCode;
}

/// An average-speed corridor: entry point A paired with exit point B.
class SpeedZone {
  const SpeedZone({required this.pointA, required this.pointB});

  final Radar pointA;
  final Radar pointB;

  String get id => '${pointA.id}-${pointB.id}';

  String get name => pointA.name;

  String get city => pointA.city;

  double get lengthMeters => Geolocator.distanceBetween(
        pointA.lat,
        pointA.lng,
        pointB.lat,
        pointB.lng,
      );

  bool get isFullyActive => pointA.isActive && pointB.isActive;

  /// The SAT-TRAKT descriptions mark built-up sections explicitly; everything
  /// else sits on a magistralni/regionalni road and gets the rural limit.
  bool get isUrban {
    final String text = name.toLowerCase();
    return text.contains('naselju') ||
        text.contains('grad ') ||
        text.contains('bulevar') ||
        text.contains('ulica');
  }

  /// Groups every `AVERAGE_SPEED_CONTROL_A` radar with its paired B point.
  static List<SpeedZone> from(List<Radar> radars) {
    final Map<String, Radar> byId = <String, Radar>{
      for (final Radar radar in radars) radar.id: radar,
    };
    final List<SpeedZone> zones = <SpeedZone>[];
    for (final Radar radar in radars) {
      if (radar.type != RadarType.averageSpeedControlA) continue;
      final Radar? partner = byId[radar.pairedWith];
      if (partner == null || partner.type != RadarType.averageSpeedControlB) {
        continue;
      }
      zones.add(SpeedZone(pointA: radar, pointB: partner));
    }
    zones.sort((SpeedZone a, SpeedZone b) {
      final int byCity = a.city.compareTo(b.city);
      return byCity != 0 ? byCity : a.pointA.id.compareTo(b.pointA.id);
    });
    return zones;
  }
}
