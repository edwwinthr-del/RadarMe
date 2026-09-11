import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../models/radar.dart';
import '../providers/filter_provider.dart';
import '../providers/location_provider.dart';
import '../providers/radar_provider.dart';
import '../utils/distance_calculator.dart';
import '../widgets/filter_bar.dart';
import '../widgets/radar_list_tile.dart';

/// Searchable, filterable list of every location, nearest first.
class RadarListScreen extends StatefulWidget {
  const RadarListScreen({super.key});

  @override
  State<RadarListScreen> createState() => _RadarListScreenState();
}

class _RadarListScreenState extends State<RadarListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FilterProvider _filters;

  @override
  void initState() {
    super.initState();
    // The query can also be cleared from the filter bar's "Poništi" chip and
    // from the map overlay, neither of which knows about this field.
    _filters = context.read<FilterProvider>()..addListener(_syncSearchField);
  }

  void _syncSearchField() {
    if (!mounted || _searchController.text == _filters.query) return;
    _searchController.value = TextEditingValue(
      text: _filters.query,
      selection: TextSelection.collapsed(offset: _filters.query.length),
    );
  }

  @override
  void dispose() {
    _filters.removeListener(_syncSearchField);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RadarProvider radarProvider = context.watch<RadarProvider>();
    final FilterProvider filters = context.watch<FilterProvider>();
    final Position? position = context.select<LocationProvider, Position?>(
      (LocationProvider provider) => provider.position,
    );

    final List<Radar> matches = filters.apply(radarProvider.radars);
    final List<RadarDistance> rows = position == null
        ? <RadarDistance>[
            for (final Radar radar in matches) RadarDistance(radar, double.nan),
          ]
        : DistanceCalculator.sortedByDistance(
            radars: matches,
            latitude: position.latitude,
            longitude: position.longitude,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Radari'),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Center(
              child: Text(
                '${rows.length}/${radarProvider.radars.length}',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: filters.setQuery,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Pretraži po lokaciji ili gradu',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: filters.query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          filters.setQuery('');
                        },
                      ),
              ),
            ),
          ),
          FilterBar(cities: radarProvider.cities),
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: rows.isEmpty
                ? _EmptyState(onClear: filters.clear)
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (BuildContext context, int index) {
                      final RadarDistance row = rows[index];
                      return RadarListTile(
                        radar: row.radar,
                        meters: row.meters.isNaN ? null : row.meters,
                        onTap: () => AppRoutes.openRadar(context, row.radar),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.travel_explore,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Nema radara za ovaj filter',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Promijenite pretragu ili poništite filtere da vidite sve lokacije.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off),
              label: const Text('Poništi filtere'),
            ),
          ],
        ),
      ),
    );
  }
}
