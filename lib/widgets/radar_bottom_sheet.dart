import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../utils/formatters.dart';
import 'capability_chip.dart';

/// Slide-up sheet shown when a map marker is tapped.
class RadarBottomSheet extends StatelessWidget {
  const RadarBottomSheet({
    super.key,
    required this.radar,
    required this.onViewDetails,
    this.meters,
  });

  final Radar radar;
  final double? meters;
  final VoidCallback onViewDetails;

  /// Opens the sheet for [radar] and resolves once it closes.
  static Future<void> show(
    BuildContext context, {
    required Radar radar,
    required VoidCallback onViewDetails,
    double? meters,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) => RadarBottomSheet(
        radar: radar,
        meters: meters,
        onViewDetails: onViewDetails,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<String> topCapabilities =
        radar.capabilities.take(4).toList(growable: false);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: radar.type.color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(radar.type.icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.sm + 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Lokacija ${radar.id}',
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        Formatters.city(radar.city),
                        style: theme.textTheme.titleMedium,
                      ),
                    ],
                  ),
                ),
                if (meters != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text('Udaljenost', style: theme.textTheme.labelSmall),
                      Text(
                        Formatters.distance(meters!),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(radar.name, style: theme.textTheme.bodyLarge),
            const SizedBox(height: AppSpacing.sm + 4),
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
                  icon: radar.isActive ? Icons.check_circle : Icons.schedule,
                ),
              ],
            ),
            if (topCapabilities.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Text('Detektuje', style: theme.textTheme.labelSmall),
              const SizedBox(height: AppSpacing.sm),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  for (final String capability in topCapabilities)
                    CapabilityGlyph(capability: capability),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton.icon(
              onPressed: onViewDetails,
              icon: const Icon(Icons.info_outline),
              label: const Text('Detalji lokacije'),
            ),
          ],
        ),
      ),
    );
  }
}
