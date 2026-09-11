import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../utils/formatters.dart';
import 'capability_chip.dart';
import 'radar_marker.dart';

/// Non-interactive hero map at the top of the detail screen.
class RadarMiniMap extends StatelessWidget {
  const RadarMiniMap({super.key, required this.radar});

  final Radar radar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: 200,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: radar.position,
          initialZoom: AppConstants.focusedZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.none,
          ),
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: AppConstants.tileUrlTemplate,
            userAgentPackageName: AppConstants.tileUserAgent,
            tileBuilder: theme.brightness == Brightness.dark
                ? darkModeTileBuilder
                : null,
          ),
          CircleLayer(
            circles: <CircleMarker>[
              CircleMarker(
                point: radar.position,
                radius: AppConstants.defaultRadiusMeters,
                useRadiusInMeter: true,
                color: radar.type.color.withValues(alpha: 0.12),
                borderColor: radar.type.color.withValues(alpha: 0.40),
                borderStrokeWidth: 1,
              ),
            ],
          ),
          MarkerLayer(
            markers: <Marker>[
              Marker(
                point: radar.position,
                width: RadarMarker.selectedSize,
                height: RadarMarker.selectedSize,
                child: RadarMarker(type: radar.type, selected: true),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Coordinates, tappable to copy.
class RadarCoordinateRow extends StatelessWidget {
  const RadarCoordinateRow({super.key, required this.radar});

  final Radar radar;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String text = Formatters.coordinates(radar.lat, radar.lng);

    return InkWell(
      borderRadius: AppRadii.buttonRadius,
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: text));
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Koordinate kopirane')),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm + 4),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: AppRadii.buttonRadius,
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.my_location, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
            Icon(
              Icons.copy,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

/// Two-column grid of everything the radar detects.
class CapabilityGrid extends StatelessWidget {
  const CapabilityGrid({super.key, required this.capabilities});

  final List<String> capabilities;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final String capability in capabilities)
              SizedBox(
                width: width,
                child: CapabilityChip(capability: capability),
              ),
          ],
        );
      },
    );
  }
}

/// Installed camera hardware, from the document's LEGENDA ELEMENATA table.
class CameraList extends StatelessWidget {
  const CameraList({super.key, required this.cameras});

  final List<CameraUnit> cameras;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      child: Column(
        children: <Widget>[
          for (int i = 0; i < cameras.length; i++) ...<Widget>[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.videocam_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(cameras[i].model),
              subtitle: Text(
                cameras[i].lanes == null
                    ? 'Broj traka nije naveden'
                    : '${cameras[i].lanes} traka',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
