import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' hide DistanceCalculator;
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../models/radar.dart';
import '../models/user_settings.dart';
import '../providers/filter_provider.dart';
import '../providers/location_provider.dart';
import '../providers/proximity_provider.dart';
import '../providers/radar_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/distance_calculator.dart';
import '../widgets/map_overlay.dart';
import '../widgets/radar_bottom_sheet.dart';
import '../widgets/radar_marker.dart';

/// Full-screen map with radar markers, alert radii and the alarm banner.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MapController _mapController = MapController();

  late final LocationProvider _location;
  bool _mapReady = false;
  bool _followUser = true;
  String? _selectedRadarId;

  @override
  void initState() {
    super.initState();
    // Listening directly keeps camera moves out of the build phase.
    _location = context.read<LocationProvider>()
      ..addListener(_handlePositionUpdate);
  }

  @override
  void dispose() {
    _location.removeListener(_handlePositionUpdate);
    super.dispose();
  }

  void _handlePositionUpdate() {
    if (!mounted || !_mapReady || !_followUser) return;
    final Position? position = _location.position;
    if (position == null) return;
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      _mapController.camera.zoom,
    );
  }

  void _recenter() {
    setState(() => _followUser = true);
    final Position? position = _location.position;
    if (position == null) {
      _location.refresh();
      return;
    }
    _mapController.move(
      LatLng(position.latitude, position.longitude),
      AppConstants.focusedZoom,
    );
  }

  void _showRadarSheet(Radar radar) {
    final Position? position = _location.position;
    setState(() => _selectedRadarId = radar.id);

    RadarBottomSheet.show(
      context,
      radar: radar,
      meters: position == null
          ? null
          : DistanceCalculator.toRadar(
              radar,
              position.latitude,
              position.longitude,
            ),
      onViewDetails: () {
        Navigator.of(context).pop();
        AppRoutes.openRadar(context, radar);
      },
    ).whenComplete(() {
      if (mounted) setState(() => _selectedRadarId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RadarProvider radarProvider = context.watch<RadarProvider>();
    final FilterProvider filters = context.watch<FilterProvider>();
    final UserSettings settings = context.watch<SettingsProvider>().settings;
    final ProximityProvider proximity = context.watch<ProximityProvider>();
    final Position? position = context.select<LocationProvider, Position?>(
      (LocationProvider provider) => provider.position,
    );

    final List<Radar> visible = filters.apply(radarProvider.radars);
    final LatLng centre = position == null
        ? AppConstants.montenegroCenter
        : LatLng(position.latitude, position.longitude);

    return Scaffold(
      body: Stack(
        children: <Widget>[
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: centre,
              initialZoom: settings.mapZoom,
              minZoom: AppConstants.minZoom,
              maxZoom: AppConstants.maxZoom,
              onMapReady: () => _mapReady = true,
              onTap: (_, __) {
                if (_selectedRadarId != null) {
                  setState(() => _selectedRadarId = null);
                }
              },
              onPositionChanged: (MapCamera camera, bool hasGesture) {
                if (hasGesture && _followUser) {
                  setState(() => _followUser = false);
                }
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: AppConstants.tileUrlTemplate,
                userAgentPackageName: AppConstants.tileUserAgent,
                maxNativeZoom: 19,
                tileBuilder: theme.brightness == Brightness.dark
                    ? darkModeTileBuilder
                    : null,
              ),
              if (settings.showRadiusCircles)
                CircleLayer(
                  circles: <CircleMarker>[
                    for (final Radar radar in visible)
                      CircleMarker(
                        point: radar.position,
                        radius: settings.alertRadiusMeters,
                        useRadiusInMeter: true,
                        color: radar.type.color.withValues(alpha: 0.10),
                        borderColor: radar.type.color.withValues(alpha: 0.35),
                        borderStrokeWidth: 1,
                      ),
                  ],
                ),
              if (position != null)
                CircleLayer(
                  circles: <CircleMarker>[
                    CircleMarker(
                      point: centre,
                      radius: position.accuracy,
                      useRadiusInMeter: true,
                      color: AppColors.userLocation.withValues(alpha: 0.12),
                      borderColor:
                          AppColors.userLocation.withValues(alpha: 0.35),
                      borderStrokeWidth: 1,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: <Marker>[
                  for (final Radar radar in visible)
                    Marker(
                      point: radar.position,
                      width: RadarMarker.selectedSize,
                      height: RadarMarker.selectedSize,
                      child: GestureDetector(
                        onTap: () => _showRadarSheet(radar),
                        child: RadarMarker(
                          type: radar.type,
                          selected: _selectedRadarId == radar.id,
                        ),
                      ),
                    ),
                ],
              ),
              if (position != null)
                MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      point: centre,
                      width: UserLocationMarker.size,
                      height: UserLocationMarker.size,
                      child: const UserLocationMarker(),
                    ),
                  ],
                ),
            ],
          ),
          MapOverlay(
            proximity: proximity,
            showRadiusCircles: settings.showRadiusCircles,
            onToggleRadiusCircles: () => context
                .read<SettingsProvider>()
                .setShowRadiusCircles(!settings.showRadiusCircles),
            onOpenNearest: () =>
                AppRoutes.openRadar(context, proximity.nearest!.radar),
            filterSummary: filters.hasActiveFilters
                ? 'Prikazano ${visible.length} od ${radarProvider.radars.length}'
                : null,
            onClearFilters: filters.clear,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _recenter,
        tooltip: 'Centriraj na moju lokaciju',
        child: Icon(_followUser ? Icons.my_location : Icons.location_searching),
      ),
    );
  }
}
