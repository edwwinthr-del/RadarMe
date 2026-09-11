import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/radar.dart';
import '../utils/formatters.dart';

/// Slides down from the top of the map while a radar is inside the alert
/// radius, pulsing so it reads at a glance without demanding attention.
class AlarmBanner extends StatefulWidget {
  const AlarmBanner({
    super.key,
    required this.radar,
    required this.meters,
    required this.onDismiss,
  });

  final Radar radar;
  final double meters;
  final VoidCallback onDismiss;

  @override
  State<AlarmBanner> createState() => _AlarmBannerState();
}

class _AlarmBannerState extends State<AlarmBanner>
    with TickerProviderStateMixin {
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color base = widget.radar.type.color;

    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, -1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: _entry,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (BuildContext context, Widget? child) {
            return Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 4,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: <Color>[
                    Color.lerp(base, Colors.black, 0.12)!,
                    Color.lerp(base, Colors.white, 0.10 + _pulse.value * 0.18)!,
                  ],
                ),
                borderRadius: AppRadii.cardRadius,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: base.withValues(alpha: 0.30 + _pulse.value * 0.25),
                    blurRadius: 16 + _pulse.value * 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.radar.type.icon,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${widget.radar.type.label} • '
                      '${Formatters.distance(widget.meters)}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.radar.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: widget.onDismiss,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.buttonRadius,
                  ),
                ),
                child: const Text('Odbaci'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
