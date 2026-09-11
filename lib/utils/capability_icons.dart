import 'package:flutter/material.dart';

/// One AI detection feature, with the Serbian wording used in the SAT-TRAKT
/// document and the icon that represents it in the UI.
class CapabilityInfo {
  const CapabilityInfo({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
  });

  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
}

/// Maps the capability keys stored in `radars.json` to labels and icons.
class CapabilityIcons {
  const CapabilityIcons._();

  static const Map<String, CapabilityInfo> _catalogue =
      <String, CapabilityInfo>{
    'instant_speed': CapabilityInfo(
      key: 'instant_speed',
      label: 'Mjerenje trenutne brzine',
      shortLabel: 'Trenutna brzina',
      icon: Icons.speed,
    ),
    'average_speed': CapabilityInfo(
      key: 'average_speed',
      label: 'Mjerenje prosječne brzine',
      shortLabel: 'Prosječna brzina',
      icon: Icons.route,
    ),
    'red_light': CapabilityInfo(
      key: 'red_light',
      label: 'Prolazak kroz crveno svjetlo',
      shortLabel: 'Crveno svjetlo',
      icon: Icons.traffic,
    ),
    'anpr': CapabilityInfo(
      key: 'anpr',
      label: 'Automatsko prepoznavanje registarskih oznaka',
      shortLabel: 'Registarske oznake',
      icon: Icons.photo_camera,
    ),
    'seatbelt': CapabilityInfo(
      key: 'seatbelt',
      label: 'Detekcija sigurnosnog pojasa',
      shortLabel: 'Sigurnosni pojas',
      icon: Icons.airline_seat_recline_normal,
    ),
    'mobile_phone': CapabilityInfo(
      key: 'mobile_phone',
      label: 'Detekcija upotrebe mobilnog telefona',
      shortLabel: 'Mobilni telefon',
      icon: Icons.phone_iphone,
    ),
    'helmet': CapabilityInfo(
      key: 'helmet',
      label: 'Detekcija kacige',
      shortLabel: 'Kaciga',
      icon: Icons.sports_motorsports,
    ),
    'vehicle_detection': CapabilityInfo(
      key: 'vehicle_detection',
      label: 'Detekcija vozila',
      shortLabel: 'Detekcija vozila',
      icon: Icons.directions_car,
    ),
    'vehicle_classification': CapabilityInfo(
      key: 'vehicle_classification',
      label: 'Klasifikacija vozila',
      shortLabel: 'Klasifikacija',
      icon: Icons.category,
    ),
    'lane_violation': CapabilityInfo(
      key: 'lane_violation',
      label: 'Nepropisno kretanje po traci',
      shortLabel: 'Kretanje po traci',
      icon: Icons.linear_scale,
    ),
    'illegal_parking': CapabilityInfo(
      key: 'illegal_parking',
      label: 'Nepropisno zaustavljanje i parkiranje',
      shortLabel: 'Parkiranje',
      icon: Icons.local_parking,
    ),
    'wrong_way': CapabilityInfo(
      key: 'wrong_way',
      label: 'Vožnja u zabranjenom smjeru',
      shortLabel: 'Zabranjeni smjer',
      icon: Icons.u_turn_left,
    ),
    'illegal_turn': CapabilityInfo(
      key: 'illegal_turn',
      label: 'Nepropisno skretanje',
      shortLabel: 'Skretanje',
      icon: Icons.turn_right,
    ),
    'illegal_overtaking': CapabilityInfo(
      key: 'illegal_overtaking',
      label: 'Nepropisno preticanje',
      shortLabel: 'Preticanje',
      icon: Icons.compare_arrows,
    ),
    'verification_video': CapabilityInfo(
      key: 'verification_video',
      label: 'Pregledni i verifikacioni video',
      shortLabel: 'Verifikacioni video',
      icon: Icons.videocam,
    ),
    'traffic_counting': CapabilityInfo(
      key: 'traffic_counting',
      label: 'Brojanje saobraćaja',
      shortLabel: 'Brojanje',
      icon: Icons.format_list_numbered,
    ),
  };

  static CapabilityInfo of(String key) =>
      _catalogue[key] ??
      CapabilityInfo(
        key: key,
        label: key,
        shortLabel: key,
        icon: Icons.help_outline,
      );

  static List<CapabilityInfo> forKeys(Iterable<String> keys) =>
      keys.map(of).toList(growable: false);
}
