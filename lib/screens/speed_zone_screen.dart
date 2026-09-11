import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../models/radar.dart';
import '../providers/filter_provider.dart';
import '../providers/proximity_provider.dart';
import '../providers/radar_provider.dart';
import '../services/speed_zone_tracker.dart';
import '../utils/formatters.dart';
import '../widgets/speed_zone_card.dart';

/// Average-speed corridors, plus the live readout while inside one.
class SpeedZoneScreen extends StatelessWidget {
  const SpeedZoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RadarProvider radarProvider = context.watch<RadarProvider>();
    final FilterProvider filters = context.watch<FilterProvider>();
    final SpeedZoneSession? session = context.select<ProximityProvider,
        SpeedZoneSession?>((ProximityProvider provider) => provider.session);

    final List<SpeedZone> zones = radarProvider.speedZones
        .where((SpeedZone zone) => _matches(zone, filters))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Zone prosječne brzine'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '${zones.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        children: <Widget>[
          if (session != null) ...<Widget>[
            ActiveSpeedZoneCard(session: session),
            const SizedBox(height: AppSpacing.lg),
          ],
          const _ExplanationCard(),
          const SizedBox(height: AppSpacing.lg),
          if (zones.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.route_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Nema zona za izabrani grad',
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
            )
          else
            for (final SpeedZone zone in zones)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm + 4),
                child: SpeedZoneCard(
                  zone: zone,
                  onTapPoint: (Radar radar) =>
                      AppRoutes.openRadar(context, radar),
                ),
              ),
        ],
      ),
    );
  }

  /// Corridors span two radars, so only the city and search filters apply here.
  static bool _matches(SpeedZone zone, FilterProvider filters) {
    if (filters.city != null && zone.city != filters.city) return false;
    if (filters.query.isEmpty) return true;
    final String needle = filters.query.toLowerCase().trim();
    return zone.name.toLowerCase().contains(needle) ||
        zone.city.toLowerCase().contains(needle) ||
        zone.pointA.id.contains(needle) ||
        zone.pointB.id.contains(needle);
  }
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

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
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Kako radi kontrola prosječne brzine',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              'Tačka A bilježi vrijeme ulaska u dionicu, a tačka B vrijeme '
              'izlaska. Sistem dijeli dužinu dionice sa proteklim vremenom i '
              'dobija prosječnu brzinu — kazna slijedi i ako ste usporili '
              'neposredno prije kamere.',
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: AppSpacing.sm + 4),
            Text(
              'RadarME počinje mjerenje kada uđete u krug od '
              '${Formatters.distance(AppConstants.speedZoneTriggerMeters)} oko '
              'tačke A i zaustavlja ga na istoj udaljenosti od tačke B.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
