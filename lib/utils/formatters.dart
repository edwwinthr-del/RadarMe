/// Display formatting shared by every screen.
class Formatters {
  const Formatters._();

  /// `240 m`, `2.4 km`, `18 km`.
  static String distance(double meters) {
    if (meters.isNaN || meters.isInfinite) return '—';
    if (meters < 1000) return '${meters.round()} m';
    final double km = meters / 1000;
    if (km < 10) return '${km.toStringAsFixed(1)} km';
    return '${km.round()} km';
  }

  /// Compact form for tight spaces such as list badges.
  static String shortDistance(double meters) {
    if (meters < 950) return '${(meters / 10).round() * 10} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  static String coordinates(double lat, double lng) =>
      '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';

  static String speed(double kilometresPerHour) =>
      '${kilometresPerHour.isFinite ? kilometresPerHour.round() : 0} km/h';

  static String radius(double meters) => '${meters.round()} m';

  /// `4:07` under an hour, `1:04:07` beyond it.
  static String duration(Duration value) {
    final int hours = value.inHours;
    final String minutes =
        (value.inMinutes % 60).toString().padLeft(hours > 0 ? 2 : 1, '0');
    final String seconds = (value.inSeconds % 60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  /// `PODGORICA` → `Podgorica`, `BIJELO POLJE` → `Bijelo Polje`.
  static String city(String value) => value
      .toLowerCase()
      .split(' ')
      .where((String word) => word.isNotEmpty)
      .map((String word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}
