import 'dart:async';

import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../services/speed_zone_tracker.dart';
import '../utils/formatters.dart';
import 'capability_chip.dart';

/// One average-speed corridor in the list: both endpoints and the road section.
class SpeedZoneCard extends StatelessWidget {
  const SpeedZoneCard({super.key, required this.zone, this.onTapPoint});

  final SpeedZone zone;
  final void Function(Radar radar)? onTapPoint;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.place_outlined, size: 15, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: AppSpacing.xs),
                Text(Formatters.city(zone.city), style: theme.textTheme.labelSmall),
                const Spacer(),
                Text(
                  Formatters.distance(zone.lengthMeters),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              zone.name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _PointRow(radar: zone.pointA, caption: 'Ulaz', onTap: onTapPoint),
            Padding(
              padding: const EdgeInsets.only(left: 15),
              child: SizedBox(
                height: 18,
                child: VerticalDivider(
                  color: theme.colorScheme.outlineVariant,
                  thickness: 2,
                  width: 2,
                ),
              ),
            ),
            _PointRow(radar: zone.pointB, caption: 'Izlaz', onTap: onTapPoint),
          ],
        ),
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  const _PointRow({required this.radar, required this.caption, this.onTap});

  final Radar radar;
  final String caption;
  final void Function(Radar radar)? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return InkWell(
      onTap: onTap == null ? null : () => onTap!(radar),
      borderRadius: AppRadii.buttonRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: radar.type.color,
                shape: BoxShape.circle,
              ),
              child: Text(
                caption == 'Ulaz' ? 'A' : 'B',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm + 4),
            Expanded(
              child: Text(
                '$caption • ${radar.id}',
                style: theme.textTheme.bodySmall,
              ),
            ),
            BadgeChip(
              label: radar.status.label,
              color:
                  radar.isActive ? AppColors.lightSuccess : AppColors.warning,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live corridor readout, shown only while the driver is between A and B.
class ActiveSpeedZoneCard extends StatefulWidget {
  const ActiveSpeedZoneCard({super.key, required this.session});

  final SpeedZoneSession session;

  @override
  State<ActiveSpeedZoneCard> createState() => _ActiveSpeedZoneCardState();
}

class _ActiveSpeedZoneCardState extends State<ActiveSpeedZoneCard> {
  late final Timer _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // The session only advances on GPS fixes, so the clock ticks here — which
    // also makes the average decay correctly while the car is stopped.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final SpeedZoneSession session = widget.session;
    final Brightness brightness = theme.brightness;

    final double average = session.averageSpeedKmh(_now);
    final Color statusColor = switch (session.statusAt(_now)) {
      SpeedZoneStatus.safe => AppColors.success(brightness),
      SpeedZoneStatus.borderline => AppColors.warning,
      SpeedZoneStatus.over => AppColors.danger(brightness),
    };

    final double total = session.travelledMeters + session.remainingMeters;
    final double progress =
        total <= 0 ? 0 : (session.travelledMeters / total).clamp(0.0, 1.0);

    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: statusColor.withValues(alpha: 0.55), width: 1.5),
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.timer_outlined, size: 18, color: statusColor),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'U zoni od tačke A',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  Formatters.duration(session.elapsedAt(_now)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              session.zone.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  Formatters.speed(average),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'ograničenje ${Formatters.speed(session.speedLimitKmh)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  'Pređeno ${Formatters.distance(session.travelledMeters)}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  'Do tačke B ${Formatters.distance(session.remainingMeters)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
