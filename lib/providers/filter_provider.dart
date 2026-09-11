import 'package:flutter/foundation.dart';

import '../models/radar.dart';

/// Search + filter state for the radar list. Kept app-wide so a filter chosen
/// on the list screen also narrows what the map and speed-zone screens show.
class FilterProvider extends ChangeNotifier {
  String _query = '';
  RadarType? _type;
  String? _city;
  RadarStatus? _status;

  String get query => _query;
  RadarType? get type => _type;
  String? get city => _city;
  RadarStatus? get status => _status;

  bool get hasActiveFilters =>
      _type != null || _city != null || _status != null || _query.isNotEmpty;

  int get activeFilterCount =>
      (_type != null ? 1 : 0) +
      (_city != null ? 1 : 0) +
      (_status != null ? 1 : 0);

  void setQuery(String value) {
    if (_query == value) return;
    _query = value;
    notifyListeners();
  }

  void setType(RadarType? value) {
    if (_type == value) return;
    _type = value;
    notifyListeners();
  }

  void setCity(String? value) {
    if (_city == value) return;
    _city = value;
    notifyListeners();
  }

  void setStatus(RadarStatus? value) {
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  void clear() {
    if (!hasActiveFilters) return;
    _query = '';
    _type = null;
    _city = null;
    _status = null;
    notifyListeners();
  }

  /// True when [radar] survives every active filter.
  bool matches(Radar radar) {
    if (_type != null && radar.type != _type) return false;
    if (_city != null && radar.city != _city) return false;
    if (_status != null && radar.status != _status) return false;
    if (_query.isEmpty) return true;

    final String needle = _query.toLowerCase().trim();
    return radar.name.toLowerCase().contains(needle) ||
        radar.city.toLowerCase().contains(needle) ||
        radar.id.contains(needle);
  }

  List<Radar> apply(List<Radar> radars) =>
      radars.where(matches).toList(growable: false);
}
