import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../providers/proximity_provider.dart';
import 'alarm_banner.dart';
import 'distance_indicator.dart';

/// Everything floating above the map: the alarm banner, the nearest-radar
/// readout, the radius toggle, and the "filters are on" chip.
class MapOverlay extends StatelessWidget {
  const MapOverlay({
    super.key,
    required this.proximity,
    required this.showRadiusCircles,
    required this.onToggleRadiusCircles,
    required this.onOpenNearest,
    this.filterSummary,
    this.onClearFilters,
  });

  final ProximityProvider proximity;
  final bool showRadiusCircles;
  final VoidCallback onToggleRadiusCircles;
  final VoidCallback onOpenNearest;

  /// e.g. "Prikazano 12 od 88"; null when no filter is active.
  final String? filterSummary;
  final VoidCallback? onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: proximity.showAlarmBanner
                    ? AlarmBanner(
                        key: ValueKey<String>(proximity.activeAlarm!.radar.id),
                        radar: proximity.activeAlarm!.radar,
                        meters: proximity.activeAlarm!.meters,
                        onDismiss: proximity.dismissAlarm,
                      )
                    : const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.sm + 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Flexible(
                    child: DistanceIndicator(
                      radar: proximity.nearest?.radar,
                      meters: proximity.nearest?.meters,
                      onTap: onOpenNearest,
                    ),
                  ),
                  const Spacer(),
                  _MapControlButton(
                    icon: showRadiusCircles
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    tooltip: 'Prikaz radijusa',
                    active: showRadiusCircles,
                    onPressed: onToggleRadiusCircles,
                  ),
                ],
              ),
              if (filterSummary != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.filter_alt_off, size: 16),
                    label: Text(filterSummary!),
                    onPressed: onClearFilters,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MapControlButton extends StatelessWidget {
  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.active,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      shape: const CircleBorder(),
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(
          icon,
          color: active
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
