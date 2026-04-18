import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_line.dart';
import '../models/stop.dart';

class UltimateCacheService {
  static const Duration _cacheValidity = Duration(hours: 24);
  static const Duration _maxCacheAge = Duration(days: 7); // خصوصية

  static SharedPreferences? _prefs;
  static bool _isInitialized = false;

  /// تهيئة SharedPreferences للويب
  static Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
    debugPrint('تم تهيئة التخزين للويب باستخدام SharedPreferences');
  }

  /// تخزين الخطوط
  static Future<bool> cacheBusLines(List<BusLine> busLines) async {
    if (!_isInitialized) await init();
    if (busLines.isEmpty) return false;

    try {
      final jsonData = jsonEncode(busLines.map((e) => e.toMap()).toList());
      await _prefs!.setString('bus_lines', jsonData);
      await _prefs!.setInt('bus_lines_timestamp', DateTime.now().millisecondsSinceEpoch);
      await _prefs!.setString('last_update', DateTime.now().toIso8601String());

      debugPrint('تم تخزين ${busLines.length} خط بنجاح');
      return true;
    } catch (e, s) {
      debugPrint('خطأ في تخزين الخطوط: $e\n$s');
      return false;
    }
  }

  /// جلب الخطوط المخزنة
  static Future<List<BusLine>?> getCachedBusLines() async {
    if (!_isInitialized) await init();

    try {
      final timestamp = _prefs!.getInt('bus_lines_timestamp');
      if (timestamp == null || !_isCacheValid(timestamp)) {
        debugPrint('التخزين منتهي الصلاحية');
        return null;
      }

      final data = _prefs!.getString('bus_lines');
      if (data == null) return null;

      final List<dynamic> list = jsonDecode(data);
      return list.map((e) => BusLine.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e, s) {
      debugPrint('خطأ في جلب الخطوط: $e\n$s');
      return null;
    }
  }

  /// تخزين المحطات
  static Future<bool> cacheStops(List<Stop> stops) async {
    if (!_isInitialized) await init();
    if (stops.isEmpty) return false;

    try {
      final jsonData = jsonEncode(stops.map((e) => e.toMap()).toList());
      await _prefs!.setString('stops', jsonData);
      await _prefs!.setInt('stops_timestamp', DateTime.now().millisecondsSinceEpoch);
      return true;
    } catch (e, s) {
      debugPrint('خطأ في تخزين المحطات: $e\n$s');
      return false;
    }
  }

  /// جلب المحطات المخزنة
  static Future<List<Stop>?> getCachedStops() async {
    if (!_isInitialized) await init();

    try {
      final timestamp = _prefs!.getInt('stops_timestamp');
      if (timestamp == null || !_isCacheValid(timestamp)) return null;

      final data = _prefs!.getString('stops');
      if (data == null) return null;

      final List<dynamic> list = jsonDecode(data);
      return list.map((e) => Stop.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e, s) {
      debugPrint('خطأ في جلب المحطات: $e\n$s');
      return null;
    }
  }

  /// جلب آخر تحديث
  static String getLastUpdate() {
    if (!_isInitialized) return 'منذ قليل';
    return _prefs!.getString('last_update') ?? 'منذ قليل';
  }

  /// حجم التخزين المؤقت
  static Future<String> getCacheSize() async {
    if (!_isInitialized) await init();
    // تقدير حجم SharedPreferences (تقريبي)
    return 'غير متاح على الويب';
  }

  /// مسح التخزين المؤقت
  static Future<bool> clearCache() async {
    if (!_isInitialized) await init();
    try {
      await _prefs!.clear();
      debugPrint('تم مسح التخزين المؤقت');
      return true;
    } catch (e) {
      debugPrint('خطأ في مسح التخزين: $e');
      return false;
    }
  }

  /// هل التخزين صالح؟
  static bool _isCacheValid(int timestamp) {
    final lastUpdate = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(lastUpdate) <= _cacheValidity;
  }

  /// هل الجهاز أوفلاين؟
  static Future<bool> isOffline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.none;
  }

  /// تحديث ذكي
  static Future<bool> shouldUpdateCache() async {
    if (await isOffline()) return false;
    final timestamp = _prefs!.getInt('bus_lines_timestamp');
    if (timestamp == null) return true;
    return !_isCacheValid(timestamp);
  }

  /// حفظ آخر خط شافه المستخدم
  static Future<void> saveLastViewedLine(BusLine line) async {
    if (!_isInitialized) await init();
    await _prefs!.setString('last_viewed_line', jsonEncode(line.toMap()));
  }

  static Future<BusLine?> getLastViewedLine() async {
    if (!_isInitialized) await init();

    try {
      final jsonStr = _prefs!.getString('last_viewed_line');
      if (jsonStr == null) return null;
      final data = jsonDecode(jsonStr);
      return BusLine.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      debugPrint('خطأ في جلب آخر خط: $e');
      return null;
    }
  }

  /// دعم فلسطين في التخزين
  static Future<void> showPalestineSupport() async {
    if (!_isInitialized) await init();
    await _prefs!.setBool('palestine_forever', true);
    await _prefs!.setString('palestine_message', 'من النهر إلى البحر... فلسطين حرة');
  }

  static bool hasShownPalestineSupport() {
    if (!_isInitialized) return false;
    return _prefs!.getBool('palestine_forever') ?? false;
  }
}
