import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';
import 'cache_service.dart'; // UltimateCacheService
import 'package:shared_preferences/shared_preferences.dart';

class UltimateDirectionsService {
  static const String _cacheBoxName = 'directions_cache';
  static late Box _cacheBox;
  static bool _isInitialized = false;

  /// تهيئة الخدمة
  static Future<void> init() async {
    if (_isInitialized) return;
    await UltimateCacheService.init();
    _cacheBox = await Hive.openBox(_cacheBoxName);
    _isInitialized = true;
  }

  /// جلب API Key من Remote Config (مع وجود مفتاح احتياطي مباشر)
  static Future<String> _getApiKey() async {
    // استخدام المفتاح الجديد كخيار افتراضي
    String apiKey = const String.fromEnvironment(
      'GOOGLE_MAPS_API_KEY',
      defaultValue: 'AIzaSyAApGehTUv-AjNJO5ByNgBSKdHP25cVdPU',
    );

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 3));
      final String remoteKey = remoteConfig.getString('google_maps_api_key');
      if (remoteKey.isNotEmpty) apiKey = remoteKey;
    } catch (e) {
      debugPrint('⚠️ Firebase Remote Config failed or empty: $e');
    }
    return apiKey;
  }

  /// جلب المسار النهائي
  static Future<Map<String, dynamic>> getSmartRoute({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [],
    bool avoidTolls = true,
    bool useTransit = false,
    bool optimizeWaypoints = false, // تم الإضافة: الباص لا يحتاج تحسين ترتيب
    bool forceOffline = false,
  }) async {
    await init();

    // Validate coordinates to prevent NaN errors
    if (origin.latitude.isNaN ||
        origin.longitude.isNaN ||
        destination.latitude.isNaN ||
        destination.longitude.isNaN ||
        waypoints.any((w) => w.latitude.isNaN || w.longitude.isNaN)) {
      debugPrint(
        'Invalid coordinates detected: origin=$origin, destination=$destination, waypoints=$waypoints',
      );
      return await _getOfflineFallback(origin, destination);
    }

    final cacheKey = _generateCacheKey(origin, destination, waypoints);

    // جرب الأوفلاين أولاً
    if (!forceOffline) {
      final cached = _cacheBox.get(cacheKey);
      if (cached != null &&
          DateTime.now().difference(cached['timestamp']) <
              const Duration(hours: 6)) {
        debugPrint('تم جلب المسار من التخزين المؤقت');
        return {
          'success': true,
          'points': cached['points'],
          'distance': cached['distance'],
          'duration': cached['duration'],
          'source': 'cache',
        };
      }
    }

    // تحقق من النت
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none) && !forceOffline) {
      return await _getOfflineFallback(origin, destination);
    }

    try {
      final apiKey = await _getApiKey();

      if (apiKey.isEmpty) {
        debugPrint(
            '⚠️ Google Maps API Key is empty! Check Remote Config or build-args.');
        return {
          'success': false,
          'error': 'مفتاح الخرائط غير متوفر. يرجى مراجعة إعدادات التطبيق.'
        };
      }

      final url = await _buildGoogleMapsUrl(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        avoidTolls: avoidTolls,
        useTransit: useTransit,
        optimizeWaypoints: optimizeWaypoints,
        apiKey: apiKey,
      );

      final response =
          await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polyline = route['overview_polyline']['points'];
          final points = _decodePolyline(polyline);

          final leg = route['legs'][0];

          // تحديث: التحقق من وجود بيانات المسافة والوقت
          if (leg['distance'] == null || leg['duration'] == null) {
            return {'success': false, 'error': 'تعذر حساب المسافة للخط الحالي'};
          }

          final distance = leg['distance']['text'];
          final duration = leg['duration']['text'];
          final durationInTraffic =
              leg['duration_in_traffic']?['text'] ?? duration;

          // حفظ في الكاش
          await _cacheBox.put(cacheKey, {
            'points': points
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList(),
            'distance': distance,
            'duration': duration,
            'timestamp': DateTime.now(),
          });

          return {
            'success': true,
            'points': points,
            'distance': distance,
            'duration': duration,
            'duration_in_traffic': durationInTraffic,
            'source': 'google',
            'traffic': durationInTraffic != duration,
          };
        } else {
          String status = data['status'] ?? 'UNKNOWN';
          String detailedError =
              data['error_message'] ?? 'تعذر الحصول على معلومات المسار';
          String errorMessage = 'خطأ في الخدمة ($status): $detailedError';

          if (data['status'] == 'REQUEST_DENIED') {
            errorMessage += '\n\n💡 نصيحة أمنية:';
            errorMessage +=
                '\n1. تأكد من تفعيل "Directions API" في لوحة تحكم Google Cloud.';
            errorMessage +=
                '\n2. إذا كان المفتاح مقيداً بـ "Android Apps"، فإنه لن يعمل مع طلبات HTTP المباشرة. يفضل إزالة قيود التطبيق أو استخدام بروكسي من السيرفر.';
            errorMessage += '\n3. تأكد من وجود حساب فوترة (Billing) نشط.';
            if (waypoints.length > 10) {
              errorMessage +=
                  '\n4. تنبيه: المسارات التي تزيد عن 10 محطات تتطلب ميزانية Directions Advanced.';
            }
          }
          return {'success': false, 'error': errorMessage};
        }
      } else {
        String errorMessage = 'HTTP ${response.statusCode}';
        if (response.statusCode == 403 || response.statusCode == 429) {
          errorMessage +=
              '\nتم رفض الطلب من جوجل. قد يكون السبب تجاوز الحصة المجانية أو قيود المفتاح.';
        }
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      debugPrint('Google Maps Error: $e');
      String errorMessage =
          'فشل في الاتصال بخدمة Google Maps (Timeout أو مشكلة شبكة)';
      if (e.toString().contains('Failed to fetch')) {
        errorMessage += '\nتحقق من الاتصال بالإنترنت ومفتاح API';
      }
      return {'success': false, 'error': errorMessage};
    }
  }

  /// بناء الرابط
  static Future<String> _buildGoogleMapsUrl({
    required LatLng origin,
    required LatLng destination,
    required List<LatLng> waypoints,
    required bool avoidTolls,
    required bool useTransit,
    required bool optimizeWaypoints,
    required String apiKey,
  }) async {
    // تم التحديث لاستخدام البروكسي من السيرفر المحلي لتجنب REQUEST_DENIED
    // نستخدم الرابط المخزن في الإعدادات أو نستخدم العنوان المحلي كافتراضي
    final prefs = await SharedPreferences.getInstance();
    final String? customUrl = prefs.getString('api_url');
    final String lang = prefs.getString('language') ?? 'العربية';
    final bool isEn = lang == 'English';

    // نصيحة: إذا كنت تستخدم محاكي أندرويد، يفضل استخدام 10.0.2.2
    final String baseUrl = customUrl ??
        (kDebugMode
            ? 'http://192.168.1.46:3001'
            : 'https://your-production-server.com');

    String url = '$baseUrl/api/proxy/directions?';
    url += 'origin=${origin.latitude},${origin.longitude}';
    url += '&destination=${destination.latitude},${destination.longitude}';

    if (waypoints.isNotEmpty) {
      // إذا كان العدد كبيراً، نأخذ عينة من المحطات (أول، وسط، آخر) لتجنب رفض جوجل للطلب
      // ولضمان بقاء المسار "انسيابياً" داخل الشوارع
      List<LatLng> sampledWaypoints = waypoints;
      if (waypoints.length > 10) {
        sampledWaypoints = [];
        int step = (waypoints.length / 10).ceil();
        for (int i = 0; i < waypoints.length; i += step) {
          sampledWaypoints.add(waypoints[i]);
        }
        // التأكد من إضافة آخر محطة دائماً
        if (!sampledWaypoints.contains(waypoints.last)) {
          sampledWaypoints.add(waypoints.last);
        }
      }
      url +=
          '&waypoints=${optimizeWaypoints ? "optimize:true|" : ""}${sampledWaypoints.map((w) => "${w.latitude},${w.longitude}").join("|")}';
    }

    url += '&mode=${useTransit ? 'transit' : 'driving'}';
    url += '&traffic_model=best_guess';
    url +=
        '&departure_time=${DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch ~/ 1000}';
    if (avoidTolls) url += '&avoid=tolls';
    url += '&key=$apiKey';
    url += '&language=${isEn ? "en" : "ar"}';

    return url;
  }

  /// فك التشفير (أسرع وأدق)
  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  /// مفتاح التخزين
  static String _generateCacheKey(
    LatLng origin,
    LatLng destination,
    List<LatLng> waypoints,
  ) {
    final String way =
        waypoints.map((w) => '${w.latitude},${w.longitude}').join('_');
    final String key =
        '${origin.latitude}_${origin.longitude}_${destination.latitude}_${destination.longitude}_$way';
    // ضمان ألا يتجاوز طول المفتاح 255 حرفاً لتجنب HiveError
    return key.length > 255 ? key.substring(0, 255) : key;
  }

  /// Fallback أوفلاين (خط مستقيم + نقاط وسيطة)
  static Future<Map<String, dynamic>> _getOfflineFallback(
    LatLng origin,
    LatLng destination,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    final points = _generateStraightLine(origin, destination, step: 0.001);
    final distance = _calculateDistance(origin, destination);

    return {
      'success': true,
      'points': points,
      'distance': '${distance.toStringAsFixed(1)} ${isEn ? "km" : "كم"}',
      'duration':
          '${(distance / 40 * 60).toStringAsFixed(0)} ${isEn ? "min" : "دقيقة"}',
      'source': 'offline_fallback',
      'warning': isEn
          ? 'Offline mode - Approximate route'
          : 'وضع عدم الاتصال - مسار تقريبي',
    };
  }

  /// خط مستقيم
  static List<LatLng> _generateStraightLine(
    LatLng start,
    LatLng end, {
    double step = 0.001,
  }) {
    final points = <LatLng>[];
    final dLat = end.latitude - start.latitude;
    final dLng = end.longitude - start.longitude;
    final steps = (dLat.abs() > dLng.abs() ? dLat.abs() : dLng.abs()) / step;

    for (int i = 0; i <= steps; i++) {
      final lat = start.latitude + (dLat * i / steps);
      final lng = start.longitude + (dLng * i / steps);
      points.add(LatLng(lat, lng));
    }
    return points;
  }

  /// حساب المسافة
  static double _calculateDistance(LatLng a, LatLng b) {
    const R = 6371; // كم
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(a.latitude * pi / 180) *
            cos(b.latitude * pi / 180) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return R * c;
  }

  /// مسار فلسطين (نقطة خاصة)
  static Future<List<LatLng>> getPalestineRoute() async {
    return [
      const LatLng(31.9474, 35.2272), // القدس
      const LatLng(32.2182, 35.2387), // نابلس
      const LatLng(31.5017, 34.4668), // غزة
    ];
  }

  /// مسح الكاش
  static Future<void> clearCache() async {
    if (!_isInitialized) await init();
    await _cacheBox.clear();
  }
}
