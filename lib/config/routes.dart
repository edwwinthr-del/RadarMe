import 'package:flutter/material.dart';

import '../models/radar.dart';
import '../screens/main_shell.dart';
import '../screens/radar_detail_screen.dart';
import '../screens/splash_screen.dart';

class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String home = '/home';
  static const String radarDetail = '/radar';

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute<void>(
          builder: (_) => const SplashScreen(),
          settings: settings,
        );
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const MainShell(),
          settings: settings,
        );
      case radarDetail:
        final Object? argument = settings.arguments;
        if (argument is! Radar) return null;
        return MaterialPageRoute<void>(
          builder: (_) => RadarDetailScreen(radar: argument),
          settings: settings,
        );
    }
    return null;
  }

  static Future<void> openRadar(BuildContext context, Radar radar) =>
      Navigator.of(context).pushNamed<void>(radarDetail, arguments: radar);
}
