import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../providers/location_provider.dart';
import '../utils/distance_calculator.dart';
import '../utils/formatters.dart';
import '../widgets/capability_chip.dart';
import '../widgets/radar_detail_sections.dart';

/// Everything known about one location, plus navigate and share actions.
class RadarDetailScreen extends StatelessWidget {
  const RadarDetailScreen({super.key, required this.radar});

  final Radar radar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Position? position = context.select<LocationProvider, Position?>(
      (LocationProvider provider) => provider.position,
    );
    final double? meters = position == null
        ? null
        : DistanceCalculator.toRadar(
            radar,
            position.latitude,
            position.longitude,
          );

    return Scaffold(
      appBar: AppBar(title: Text('Lokacija ${radar.id}')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppSpacing.xl),
        children: <Widget>[
          RadarMiniMap(radar: radar),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(radar.name, style: theme.textTheme.titleLarge),
                const SizedBox(height: AppSpacing.sm + 4),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.place_outlined,
                      size: 17,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs + 2),
                    Text(
                      Formatters.city(radar.city),
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (meters != null) ...<Widget>[
                      const Spacer(),
                      Icon(
                        Icons.straighten,
                        size: 17,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: AppSpacing.xs + 2),
                      Text(
                        Formatters.distance(meters),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    BadgeChip(
                      label: radar.type.label,
                      color: radar.type.color,
                      icon: radar.type.icon,
                    ),
                    BadgeChip(
                      label: radar.status.label,
                      color: radar.isActive
                          ? AppColors.lightSuccess
                          : AppColors.warning,
                      icon:
                          radar.isActive ? Icons.check_circle : Icons.schedule,
                    ),
                    if (radar.pairedWith != null)
                      BadgeChip(
                        label: 'Par: ${radar.pairedWith}',
                        color: theme.colorScheme.primary,
                        icon: Icons.link,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                RadarCoordinateRow(radar: radar),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Šta ovaj radar detektuje',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm + 4),
                CapabilityGrid(capabilities: radar.capabilities),
                if (radar.cameras.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  Text('Kamere na lokaciji', style: theme.textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm + 4),
                  CameraList(cameras: radar.cameras),
                ],
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _navigate(radar),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigiraj'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 4),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _share(radar),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('Podijeli'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Hands the coordinates to the platform's maps app, with a web fallback.
  static Future<void> _navigate(Radar radar) async {
    final Uri primary = Platform.isIOS
        ? Uri.parse(
            'https://maps.apple.com/?daddr=${radar.lat},${radar.lng}&dirflg=d')
        : Uri.parse('google.navigation:q=${radar.lat},${radar.lng}');

    // A device with no maps app throws rather than returning false, so both
    // outcomes have to fall through to the browser.
    bool opened = false;
    try {
      opened = await launchUrl(primary, mode: LaunchMode.externalApplication);
    } catch (error) {
      opened = false;
    }
    if (opened) return;

    await launchUrl(
      Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${radar.lat},${radar.lng}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  static Future<void> _share(Radar radar) => Share.share(
        '${radar.name} (${Formatters.city(radar.city)})\n'
        '${radar.type.label}\n'
        '${Formatters.coordinates(radar.lat, radar.lng)}\n'
        'https://www.google.com/maps/search/?api=1'
        '&query=${radar.lat},${radar.lng}',
        subject: '${AppConstants.appName} — lokacija ${radar.id}',
      );
}
