import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'config/constants.dart';
import 'config/routes.dart';
import 'config/theme.dart';
import 'providers/settings_provider.dart';

class RadarMeApp extends StatelessWidget {
  const RadarMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeMode themeMode = context.select<SettingsProvider, ThemeMode>(
      (SettingsProvider provider) => provider.themeMode,
    );

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
