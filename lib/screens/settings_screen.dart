import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../models/user_settings.dart';
import '../providers/location_provider.dart';
import '../providers/radar_provider.dart';
import '../providers/settings_provider.dart';
import '../services/alarm_service.dart';
import '../utils/formatters.dart';
import '../widgets/settings_tiles.dart';

/// Every user preference, grouped the way the driver thinks about them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final SettingsProvider provider = context.watch<SettingsProvider>();
    final UserSettings settings = provider.settings;
    final RadarProvider radars = context.watch<RadarProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Podešavanja')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: <Widget>[
          SettingsSection(
            title: 'Upozorenja',
            children: <Widget>[
              SettingsSlider(
                label: 'Radijus upozorenja',
                value: settings.alertRadiusMeters,
                min: AppConstants.minRadiusMeters,
                max: AppConstants.maxRadiusMeters,
                divisions: AppConstants.radiusSliderDivisions,
                display: Formatters.radius(settings.alertRadiusMeters),
                onChanged: provider.setAlertRadius,
              ),
              SwitchListTile(
                value: settings.soundEnabled,
                onChanged: provider.setSoundEnabled,
                title: const Text('Zvuk'),
                subtitle: const Text('Ton se čuje i kada je zvono isključeno'),
                secondary: IconButton(
                  tooltip: 'Preslušaj',
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () => context
                      .read<AlarmService>()
                      .playSound(settings.alarmSoundId),
                ),
              ),
              SwitchListTile(
                value: settings.vibrationEnabled,
                onChanged: provider.setVibrationEnabled,
                title: const Text('Vibracija'),
                secondary: const Icon(Icons.vibration),
              ),
              SwitchListTile(
                value: settings.notificationsEnabled,
                onChanged: provider.setNotificationsEnabled,
                title: const Text('Obavještenja'),
                secondary: const Icon(Icons.notifications_active_outlined),
              ),
              const Divider(height: AppSpacing.lg),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Ton alarma'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    for (final AlarmSound sound in AlarmSound.all)
                      ChoiceChip(
                        label: Text(sound.label),
                        selected: settings.alarmSoundId == sound.id,
                        onSelected: (_) {
                          provider.setAlarmSound(sound.id);
                          context.read<AlarmService>().playSound(sound.id);
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
          SettingsSection(
            title: 'Prikaz',
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.sm,
                ),
                child: SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('Sistem'),
                      icon: Icon(Icons.brightness_auto),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Svijetla'),
                      icon: Icon(Icons.light_mode),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Tamna'),
                      icon: Icon(Icons.dark_mode),
                    ),
                  ],
                  selected: <ThemeMode>{settings.themeMode},
                  onSelectionChanged: (Set<ThemeMode> selection) =>
                      provider.setThemeMode(selection.first),
                ),
              ),
              SwitchListTile(
                value: settings.showRadiusCircles,
                onChanged: provider.setShowRadiusCircles,
                title: const Text('Radijus na mapi'),
                subtitle: const Text('Krug oko svakog radara'),
                secondary: const Icon(Icons.circle_outlined),
              ),
              SettingsSlider(
                label: 'Početni zum mape',
                value: settings.mapZoom,
                min: 10,
                max: 17,
                divisions: 14,
                display: settings.mapZoom.toStringAsFixed(1),
                onChanged: provider.setMapZoom,
              ),
            ],
          ),
          SettingsSection(
            title: 'Koji radari aktiviraju alarm',
            children: <Widget>[
              for (final RadarType type in <RadarType>[
                RadarType.intersectionEnforcement,
                RadarType.roadEnforcementPoint,
                RadarType.averageSpeedControlA,
              ])
                SwitchListTile(
                  value: settings.alertsFor(type),
                  onChanged: (bool value) =>
                      provider.setAlertForType(type, value),
                  title: Text(
                    type == RadarType.averageSpeedControlA
                        ? 'Zone prosječne brzine'
                        : type.label,
                  ),
                  secondary: Icon(type.icon, color: type.color),
                ),
            ],
          ),
          SettingsSection(
            title: 'Ograničenja brzine u zonama',
            children: <Widget>[
              SettingsSlider(
                label: 'Naselje',
                value: settings.urbanSpeedLimitKmh,
                min: AppConstants.minSpeedLimitKmh,
                max: AppConstants.maxSpeedLimitKmh,
                divisions: 20,
                display: Formatters.speed(settings.urbanSpeedLimitKmh),
                onChanged: provider.setUrbanSpeedLimit,
              ),
              SettingsSlider(
                label: 'Van naselja',
                value: settings.ruralSpeedLimitKmh,
                min: AppConstants.minSpeedLimitKmh,
                max: AppConstants.maxSpeedLimitKmh,
                divisions: 20,
                display: Formatters.speed(settings.ruralSpeedLimitKmh),
                onChanged: provider.setRuralSpeedLimit,
              ),
            ],
          ),
          SettingsSection(
            title: 'Praćenje u pozadini',
            children: <Widget>[
              SwitchListTile(
                value: settings.backgroundTrackingEnabled,
                onChanged: (bool value) => _toggleBackground(context, value),
                title: const Text('Upozoravaj i kada je aplikacija zatvorena'),
                subtitle: const Text(
                  'RadarME nastavlja da prati lokaciju dok vozite. '
                  'Troši nešto više baterije.',
                ),
                secondary: const Icon(Icons.gps_fixed),
                isThreeLine: true,
              ),
            ],
          ),
          SettingsSection(
            title: 'O aplikaciji',
            children: <Widget>[
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Verzija'),
                trailing: Text(AppConstants.appVersion),
              ),
              const ListTile(
                leading: Icon(Icons.dataset_outlined),
                title: Text('Izvor podataka'),
                trailing: Text(AppConstants.dataSource),
              ),
              ListTile(
                leading: const Icon(Icons.sensors),
                title: const Text('Broj radara'),
                trailing: Text('${radars.radars.length}'),
              ),
              ListTile(
                leading: Icon(
                  radars.source == RadarDataSource.firestore
                      ? Icons.cloud_done_outlined
                      : Icons.sd_storage_outlined,
                ),
                title: const Text('Podaci učitani iz'),
                trailing: Text(
                  radars.source == RadarDataSource.firestore
                      ? 'Firestore'
                      : 'Lokalne kopije',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Enabling background alerts needs "Always" location, notifications, and —
  /// on aggressive OEMs — an exemption from battery optimisation.
  static Future<void> _toggleBackground(
    BuildContext context,
    bool value,
  ) async {
    final SettingsProvider settings = context.read<SettingsProvider>();
    if (!value) {
      await settings.setBackgroundTracking(false);
      return;
    }

    final LocationProvider location = context.read<LocationProvider>();
    final AlarmService alarm = context.read<AlarmService>();

    final bool granted = await location.requestBackgroundPermission();
    if (!context.mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Potrebna je dozvola za lokaciju „Uvijek“ da bi pozadinsko '
            'praćenje radilo.',
          ),
          action: SnackBarAction(
            label: 'Podešavanja',
            onPressed: location.openSettings,
          ),
        ),
      );
      return;
    }

    await alarm.requestNotificationPermission();
    await location.requestIgnoreBatteryOptimizations();
    await settings.setBackgroundTracking(true);
  }
}
