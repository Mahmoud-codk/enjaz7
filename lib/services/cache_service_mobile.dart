import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/bus_line.dart';
import '../models/stop.dart';

class UltimateCacheService {
  static const String _boxName = 'bus_guide_cache';
  static const Duration _cacheValidity = Duration(hours: 24);
  static const Duration _maxCacheAge = Duration(days: 7); // خصوصية

  static late Box _box;
  static bool _isInitialized = false;

  /// تهيئة Hive للأجهزة
  static Future<void> init() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // تسجيل Adapters — سجِّل فقط إذا لم تُسجّل مسبقًا لتجنب الخطأ
    try {
      if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(BusLineAdapter());
    } catch (e) {
      debugPrint('تحذير: فشل التحقق من BusLineAdapter: $e');
    }
    try {
      if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(StopAdapter());
    } catch (e) {
      debugPrint('تحذير: فشل التحقق من StopAdapter: $e');
    }

    _box = await Hive.openBox(_boxName);
    _isInitialized = true;

    // تنظيف تلقائي للبيانات القديمة
    await _autoCleanup();
  }

  /// تخزين الخطوط
  static Future<bool> cacheBusLines(List<BusLine> busLines) async {
    if (!_isInitialized) await init();
    if (busLines.isEmpty) return false;

    try {
      final compressed = gzip.encode(utf8.encode(jsonEncode(busLines.map((e) => e.toMap()).toList())));
      await _box.put('bus_lines', compressed);
      await _box.put('bus_lines_timestamp', DateTime.now().millisecondsSinceEpoch);
      await _box.put('last_update', DateTime.now().toIso8601String());

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
      final timestamp = _box.get('bus_lines_timestamp');
      if (timestamp == null || !_isCacheValid(timestamp)) {
        debugPrint('التخزين منتهي الصلاحية');
        return null;
      }

      final compressed = _box.get('bus_lines');
      if (compressed == null) return null;

      final jsonString = utf8.decode(gzip.decode(compressed));
      final List<dynamic> list = jsonDecode(jsonString);
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
      final compressed = gzip.encode(utf8.encode(jsonEncode(stops.map((e) => e.toMap()).toList())));
      await _box.put('stops', compressed);
      await _box.put('stops_timestamp', DateTime.now().millisecondsSinceEpoch);
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
      final timestamp = _box.get('stops_timestamp');
      if (timestamp == null || !_isCacheValid(timestamp)) return null;

      final compressed = _box.get('stops');
      if (compressed == null) return null;

      final jsonString = utf8.decode(gzip.decode(compressed));
      final List<dynamic> list = jsonDecode(jsonString);
      return list.map((e) => Stop.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (e, s) {
      debugPrint('خطأ في جلب المحطات: $e\n$s');
      return null;
    }
  }

  /// جلب آخر تحديث
  static String getLastUpdate() {
    if (!_isInitialized) return 'منذ قليل';
    return _box.get('last_update', defaultValue: 'منذ قليل');
  }

  /// حجم التخزين المؤقت
  static Future<String> getCacheSize() async {
    if (!_isInitialized) await init();
    final dir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${dir.path}/hive');
    if (!cacheDir.existsSync()) return '0 KB';

    int totalSize = 0;
    cacheDir.listSync(recursive: true).forEach((file) {
      if (file is File) totalSize += file.lengthSync();
    });

    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) return '${(totalSize / 1024).toStringAsFixed(1)} KB';
    return '${(totalSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// مسح التخزين المؤقت
  static Future<bool> clearCache() async {
    if (!_isInitialized) await init();
    try {
      await _box.clear();
      debugPrint('تم مسح التخزين المؤقت');
      return true;
    } catch (e) {
      debugPrint('خطأ في مسح التخزين: $e');
      return false;
    }
  }

  /// تنظيف تلقائي
  static Future<void> _autoCleanup() async {
    try {
      final keys = _box.keys.toList();
      final now = DateTime.now();

      for (var key in keys) {
        if (key is String && key.endsWith('_timestamp')) {
          final timestamp = _box.get(key);
          if (timestamp != null) {
            final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
            if (now.difference(date) > _maxCacheAge) {
              final dataKey = key.replaceAll('_timestamp', '');
              await _box.delete(dataKey);
              await _box.delete(key);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('خطأ في التنظيف التلقائي: $e');
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
    final timestamp = _box.get('bus_lines_timestamp');
    if (timestamp == null) return true;
    return !_isCacheValid(timestamp);
  }

  /// حفظ آخر خط شافه المستخدم
  static Future<void> saveLastViewedLine(BusLine line) async {
    if (!_isInitialized) await init();
    await _box.put('last_viewed_line', line.toMap());
  }

  static Future<BusLine?> getLastViewedLine() async {
    if (!_isInitialized) await init();
    final data = _box.get('last_viewed_line');
    if (data == null) return null;
    return BusLine.fromMap(Map<String, dynamic>.from(data));
  }

  /// دعم فلسطين في التخزين
  static Future<void> showPalestineSupport() async {
    if (!_isInitialized) await init();
    await _box.put('palestine_forever', true);
    await _box.put('palestine_message', 'من النهر إلى البحر... فلسطين حرة');
  }

  static bool hasShownPalestineSupport() {
    if (!_isInitialized) return false;
    return _box.get('palestine_forever', defaultValue: false);
  }
}
