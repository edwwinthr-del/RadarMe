import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../utils/formatters.dart';

/// Always-on readout of the nearest radar. The number tweens between values so
/// it counts down smoothly instead of jumping on every GPS fix.
class DistanceIndicator extends StatelessWidget {
  const DistanceIndicator({
    super.key,
    required this.radar,
    required this.meters,
    this.onTap,
  });

  final Radar? radar;
  final double? meters;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Radar? target = radar;

    return Material(
      color: theme.colorScheme.surface,
      elevation: 3,
      borderRadius: AppRadii.cardRadius,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: target == null ? null : onTap,
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 2,
          ),
          child: target == null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      Icons.gps_off,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text('Čeka se GPS…', style: theme.textTheme.bodySmall),
                  ],
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: target.type.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Najbliži radar',
                          style: theme.textTheme.labelSmall,
                        ),
                        _AnimatedDistance(meters: meters ?? 0),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm + 2),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _AnimatedDistance extends StatelessWidget {
  const _AnimatedDistance({required this.meters});

  final double meters;

  @override
  Widget build(BuildContext context) {
    // TweenAnimationBuilder restarts from the value currently on screen each
    // time `end` changes, which is what produces the smooth count-down.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: meters),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (BuildContext context, double value, Widget? child) => Text(
        Formatters.distance(value),
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}
