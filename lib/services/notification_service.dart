import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService extends ChangeNotifier {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _countKey = 'notification_count';
  static const String _notificationsKey = 'notifications_list';

  // Live reactive counter
  final ValueNotifier<int> notificationCount = ValueNotifier<int>(0);
  
  // Persistent notifications history
  List<String> _notifications = [];
  List<String> get notifications => List.unmodifiable(_notifications);

  // Deduplication for proximity (private)
  final Set<String> _notifiedStations = <String>{};

  /// Initialize service (call once in main.dart)
  Future<void> initialize() async {
    await _loadFromPrefs();
    notificationCount.value = _notifications.length;
  }

  /// Load from SharedPreferences
  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt(_countKey) ?? 0;
      notificationCount.value = count;
      
      final notificationsJson = prefs.getStringList(_notificationsKey) ?? [];
      _notifications = notificationsJson;
    } catch (e) {
      debugPrint('Error loading notifications: $e');
    }
  }

  /// Save to SharedPreferences
  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_countKey, notificationCount.value);
      await prefs.setStringList(_notificationsKey, _notifications);
    } catch (e) {
      debugPrint('Error saving notifications: $e');
    }
  }

  /// Add new notification (FCM or proximity)
  Future<void> addNotification({
    required String message,
    String? stationId,
    bool vibrate = false,
  }) async {
    if (!kIsWeb) {
      if (vibrate) {
        // Vibration.vibrate(duration: 500); // Add dependency if needed
      }
    }

    // Deduplication for stations
    if (stationId != null && _notifiedStations.contains(stationId)) {
      return; // Already notified
    }
    if (stationId != null) {
      _notifiedStations.add(stationId);
    }

    _notifications.insert(0, '${DateTime.now().toString().substring(11, 16)} - $message');
    
    // Keep only last 50
    if (_notifications.length > 50) {
      _notifications = _notifications.sublist(0, 50);
    }

    notificationCount.value++;
    notifyListeners();
    await _saveToPrefs();
  }

  /// Reset badge count
  Future<void> reset() async {
    notificationCount.value = 0;
    _notifications.clear();
    _notifiedStations.clear();
    notifyListeners();
    await _saveToPrefs();
  }

  /// Clear history only (keep badge)
  Future<void> clearHistory() async {
    _notifications.clear();
    notifyListeners();
    await _saveToPrefs();
  }
}
