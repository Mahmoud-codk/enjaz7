import 'dart:math';
import 'stop.dart';

class RouteModel {
  final Stop startStop;
  final Stop endStop;
  final List<Stop> stops;
  final String routeName;
  final String routeType;

  RouteModel({
    required this.startStop,
    required this.endStop,
    List<Stop>? stops,
    this.routeName = '',
    this.routeType = 'bus',
  }) : stops = stops ?? [];

  // -----------------------------------------------------------------
  // تحويل الكائن إلى Map (للتخزين في Firestore أو SharedPreferences)
  // -----------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'startStop': startStop.toMap(),
      'endStop': endStop.toMap(),
      'stops': stops.map((s) => s.toMap()).toList(),
      'routeName': routeName,
      'routeType': routeType,
    };
  }

  // -----------------------------------------------------------------
  // إنشاء كائن من Map (مع حماية كاملة من null وأنواع خاطئة)
  // -----------------------------------------------------------------
  factory RouteModel.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return RouteModel(
        startStop: Stop.empty(),
        endStop: Stop.empty(),
        stops: [],
        routeName: '',
        routeType: 'bus',
      );
    }

    try {
      final startMap = map['startStop'] as Map<String, dynamic>?;
      final endMap = map['endStop'] as Map<String, dynamic>?;
      final stopsList = map['stops'] as List<dynamic>?;

      return RouteModel(
        startStop: startMap != null
            ? Stop.fromMap(Map<String, dynamic>.from(startMap))
            : Stop.empty(),
        endStop: endMap != null
            ? Stop.fromMap(Map<String, dynamic>.from(endMap))
            : Stop.empty(),
        stops: stopsList != null
            ? stopsList
                .whereType<Map<String, dynamic>>()
                .map((s) => Stop.fromMap(s))
                .toList()
            : [],
        routeName: map['routeName']?.toString() ?? '',
        routeType: map['routeType']?.toString() ?? 'bus',
      );
    } catch (e) {
      // لو حصل أي خطأ في التحويل، نرجع كائن آمن
      return RouteModel(
        startStop: Stop.empty(),
        endStop: Stop.empty(),
        stops: [],
      );
    }
  }

  // -----------------------------------------------------------------
  // نسخة معدلة (copyWith)
  // -----------------------------------------------------------------
  RouteModel copyWith({
    Stop? startStop,
    Stop? endStop,
    List<Stop>? stops,
    String? routeName,
    String? routeType,
  }) {
    return RouteModel(
      startStop: startStop ?? this.startStop,
      endStop: endStop ?? this.endStop,
      stops: stops ?? this.stops,
      routeName: routeName ?? this.routeName,
      routeType: routeType ?? this.routeType,
    );
  }

  // -----------------------------------------------------------------
  // كل النقاط المطلوبة لرسم الـ Polyline
  // -----------------------------------------------------------------
  List<Stop> getAllPoints() {
    // نتأكد إن البداية والنهاية مش موجودين في stops عشان ما يتكرروش
    final middle = stops.where((s) => s != startStop && s != endStop).toList();
    return [startStop, ...middle, endStop];
  }

  // -----------------------------------------------------------------
  // المسافة الكلية (حساب حقيقي باستخدام Haversine)
  // -----------------------------------------------------------------
  double getTotalDistance() {
    final points = getAllPoints();
    if (points.length < 2) return 0.0;

    double total = 0.0;
    for (int i = 0; i < points.length - 1; i++) {
      total += _haversine(
        points[i].lat,
        points[i].lng,
        points[i + 1].lat,
        points[i + 1].lng,
      );
    }
    return total; // بالكيلومتر
  }

  // دالة Haversine لحساب المسافة بين نقطتين
  static double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0; // نصف قطر الأرض بالكيلومتر
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _toRadians(double degrees) => degrees * (pi / 180);

  // -----------------------------------------------------------------
  // الوقت المتوقع (تقدير بسيط: 50 كم/ساعة للباص)
  // -----------------------------------------------------------------
  String getEstimatedDuration() {
    final distanceKm = getTotalDistance();
    if (distanceKm <= 0) return 'غير محدد';

    const averageSpeedKph = 50.0; // يمكنك تغييره حسب نوع الخط
    final hours = distanceKm / averageSpeedKph;

    if (hours < 1) {
      final minutes = (hours * 60).round();
      return '$minutes دقيقة';
    } else {
      final h = hours.floor();
      final m = ((hours - h) * 60).round();
      return m == 0 ? '$h ساعة' : '$h ساعة و $m دقيقة';
    }
  }

  // -----------------------------------------------------------------
  // مقارنة الكائنات
  // -----------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RouteModel &&
        other.startStop == startStop &&
        other.endStop == endStop &&
        _listEquals(other.stops, stops) &&
        other.routeName == routeName &&
        other.routeType == routeType;
  }

  static bool _listEquals(List<Stop>? a, List<Stop>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(
      startStop,
      endStop,
      Object.hashAll(stops),
      routeName,
      routeType,
    );
  }

  @override
  String toString() {
    return 'RouteModel(name: "$routeName", type: $routeType, '
        'from: ${startStop.name}, to: ${endStop.name}, '
        'stops: ${stops.length}, distance: ${getTotalDistance().toStringAsFixed(1)} كم)';
  }
}