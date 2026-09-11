import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../utils/capability_icons.dart';

/// Icon + Serbian label for one AI detection feature.
class CapabilityChip extends StatelessWidget {
  const CapabilityChip({
    super.key,
    required this.capability,
    this.compact = false,
  });

  final String capability;

  /// Compact chips use the short label and fit into a horizontal run.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final CapabilityInfo info = CapabilityIcons.of(capability);
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + (compact ? 0 : 2),
        vertical: compact ? AppSpacing.xs + 2 : AppSpacing.sm + 2,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: AppRadii.buttonRadius,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Icon(
            info.icon,
            size: compact ? 16 : 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              compact ? info.shortLabel : info.label,
              style: compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Icon-only variant used where space is tight, e.g. the marker bottom sheet.
class CapabilityGlyph extends StatelessWidget {
  const CapabilityGlyph({super.key, required this.capability});

  final String capability;

  @override
  Widget build(BuildContext context) {
    final CapabilityInfo info = CapabilityIcons.of(capability);
    final ThemeData theme = Theme.of(context);

    return Tooltip(
      message: info.label,
      child: SizedBox(
        width: 68,
        child: Column(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(info.icon, size: 21, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              info.shortLabel,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// Coloured pill for a radar type or status.
class BadgeChip extends StatelessWidget {
  const BadgeChip({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.filled = true,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.14) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadii.chip),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: AppSpacing.xs + 2),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
