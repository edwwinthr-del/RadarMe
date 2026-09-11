import 'package:flutter/material.dart';

import '../config/constants.dart';
import '../models/radar.dart';

/// Map pin for one radar: a small circular badge carrying the type symbol.
class RadarMarker extends StatelessWidget {
  const RadarMarker({super.key, required this.type, this.selected = false});

  final RadarType type;
  final bool selected;

  /// Marker box size; the map layer sizes its `Marker` to match.
  static const double size = 34;
  static const double selectedSize = 44;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        width: selected ? selectedSize : size,
        height: selected ? selectedSize : size,
        decoration: BoxDecoration(
          color: type.color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          type.icon,
          size: selected ? 22 : 17,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// The driver's own position: a solid dot with a ripple pulsing outwards.
class UserLocationMarker extends StatefulWidget {
  const UserLocationMarker({super.key});

  static const double size = 46;

  @override
  State<UserLocationMarker> createState() => _UserLocationMarkerState();
}

class _UserLocationMarkerState extends State<UserLocationMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = _controller.value;
        return Center(
          child: SizedBox(
            width: UserLocationMarker.size,
            height: UserLocationMarker.size,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Container(
                  width: UserLocationMarker.size * t,
                  height: UserLocationMarker.size * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.userLocation
                        .withValues(alpha: (1 - t) * 0.30),
                  ),
                ),
                child!,
              ],
            ),
          ),
        );
      },
      child: Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.userLocation,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 5,
            ),
          ],
        ),
      ),
    );
  }
}
