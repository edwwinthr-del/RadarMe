import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/constants.dart';
import '../config/routes.dart';
import '../providers/location_provider.dart';
import '../providers/radar_provider.dart';
import '../providers/settings_provider.dart';

/// Loads the radar dataset and asks for location permission, then hands over to
/// the main shell. Stays up for at least [AppConstants.splashMinimumDuration].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final RadarProvider radars = context.read<RadarProvider>();
    final LocationProvider location = context.read<LocationProvider>();
    final SettingsProvider settings = context.read<SettingsProvider>();

    // Nothing in here may strand the driver on the splash screen: a plugin that
    // throws, a permission dialog that errors, a service that refuses to start.
    // The bundled dataset is always there, so the map is still worth reaching.
    try {
      await Future.wait<Object?>(<Future<Object?>>[
        radars.load(),
        location.initialize(),
      ]);
      await settings.syncBackgroundService();
    } catch (error) {
      developer.log(
        'Pokretanje nije završeno u cijelosti.',
        name: 'SplashScreen',
        error: error,
      );
    }

    final Duration remaining =
        AppConstants.splashMinimumDuration - stopwatch.elapsed;
    if (remaining > Duration.zero) await Future<void>.delayed(remaining);

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.lightPrimary,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              AppColors.lightPrimary,
              AppColors.lightPrimaryVariant,
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SizedBox(
                width: 160,
                height: 160,
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (BuildContext context, _) =>
                      CustomPaint(painter: _RadarSweepPainter(_controller.value)),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Radari u Crnoj Gori',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three arcs expanding away from a dot, redrawn from the animation value.
class _RadarSweepPainter extends CustomPainter {
  const _RadarSweepPainter(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset centre = Offset(size.width / 2, size.height / 2);
    final double maxRadius = size.width / 2;

    for (int ring = 0; ring < 3; ring++) {
      final double t = (progress + ring / 3) % 1.0;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white.withValues(alpha: (1 - t) * 0.75);
      canvas.drawCircle(centre, maxRadius * t, paint);
    }

    canvas.drawCircle(centre, 12, Paint()..color = Colors.white);
    canvas.drawCircle(centre, 5, Paint()..color = AppColors.lightAccent);
  }

  @override
  bool shouldRepaint(_RadarSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
