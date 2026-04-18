import 'package:shared_preferences/shared_preferences.dart';

class AppStateService {
  static const String _startKey = 'trip_start';
  static const String _endKey = 'trip_end';
  static const String _targetStationKey = 'trip_target_station';
  static const String _notificationEnabledKey = 'trip_notifications_enabled';

  /// Save complete trip state
  static Future<void> saveTrip({
    required String? start,
    required String? end,
    required String? targetStation,
    required bool notificationEnabled,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_startKey, start ?? '');
    await prefs.setString(_endKey, end ?? '');
    await prefs.setString(_targetStationKey, targetStation ?? '');
    await prefs.setBool(_notificationEnabledKey, notificationEnabled);
  }

  /// Load complete trip state with defaults
  static Future<Map<String, dynamic>> loadTrip() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'start': prefs.getString(_startKey) ?? '',
      'end': prefs.getString(_endKey) ?? '',
      'targetStation': prefs.getString(_targetStationKey) ?? '',
      'notificationEnabled': prefs.getBool(_notificationEnabledKey) ?? false,
    };
  }

  /// Clear trip state
  static Future<void> clearTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_startKey);
    await prefs.remove(_endKey);
    await prefs.remove(_targetStationKey);
    await prefs.remove(_notificationEnabledKey);
  }
}
