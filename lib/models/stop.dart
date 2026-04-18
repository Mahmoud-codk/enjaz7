import 'dart:math' show cos, sqrt, asin, sin, pi, pow;
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/station_translation_service.dart';

part 'stop.g.dart';

@HiveType(typeId: 2)
class Stop {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double lat;
  @HiveField(2)
  final double lng;

  const Stop({
    required this.name,
    required this.lat,
    required this.lng,
  });

  /// جلب الاسم بناءً على اللغة
  String getLocalizedName(Locale locale) {
    if (locale.languageCode == 'en') {
      return StationTranslationService().translate(name);
    }
    return name;
  }

  // -----------------------------------------------------------------
  // كائن فارغ آمن (بدل ما ترجع null)
  // -----------------------------------------------------------------
  factory Stop.empty() {
    return const Stop(name: '', lat: 0.0, lng: 0.0);
  }

  // -----------------------------------------------------------------
  // تحويل إلى Map (لـ Firestore, SharedPreferences, JSON)
  // -----------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
    };
  }

  // -----------------------------------------------------------------
  // إنشاء من Map (يدعم أسماء متعددة للإحداثيات)
  // -----------------------------------------------------------------
  factory Stop.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return Stop.empty();
    }

    try {
      final double latitude = _parseDouble(map['lat'] ?? map['latitude'] ?? 0.0);
      final double longitude = _parseDouble(map['lng'] ?? map['longitude'] ?? 0.0);
      final String stopName = (map['name'] ?? map['stop_name'] ?? '').toString();

      return Stop(
        name: stopName,
        lat: latitude,
        lng: longitude,
      );
    } catch (e) {
      return Stop.empty();
    }
  }

  // دالة مساعدة لتحويل أي قيمة إلى double بأمان
  static double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // -----------------------------------------------------------------
  // نسخة معدلة
  // -----------------------------------------------------------------
  Stop copyWith({
    String? name,
    double? lat,
    double? lng,
  }) {
    return Stop(
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
    );
  }

  // -----------------------------------------------------------------
  // التحقق من صحة الإحداثيات
  // -----------------------------------------------------------------
  bool get hasValidCoordinates {
    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180 &&
        lat != 0.0 &&
        lng != 0.0;
  }

  // -----------------------------------------------------------------
  // حساب المسافة بين هذه المحطة ومحطة أخرى (بالكيلومتر)
  // -----------------------------------------------------------------
  double distanceTo(Stop other) {
    if (!hasValidCoordinates || !other.hasValidCoordinates) {
      return double.infinity;
    }

    const double earthRadius = 6371.0; // km
    final double dLat = _toRadians(other.lat - lat);
    final double dLng = _toRadians(other.lng - lng);

    final double a = pow(sin(dLat / 2), 2) +
        cos(_toRadians(lat)) *
            cos(_toRadians(other.lat)) *
            pow(sin(dLng / 2), 2);

    final double c = 2 * asin(sqrt(a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) {
    return degrees * (pi / 180);
  }

  // -----------------------------------------------------------------
  // مقارنة الكائنات
  // -----------------------------------------------------------------
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Stop &&
        other.name == name &&
        other.lat == lat &&
        other.lng == lng;
  }

  @override
  int get hashCode {
    return Object.hash(name, lat, lng);
  }

  // -----------------------------------------------------------------
  // عرض جميل للـ debug
  // -----------------------------------------------------------------
  @override
  String toString() {
    if (name.isEmpty) {
      return 'Stop(غير معروف, $lat, $lng)';
    }
    return 'Stop("$name", $lat, $lng)';
  }

  // -----------------------------------------------------------------
  // للتوافق مع الكود القديم
  // -----------------------------------------------------------------
  double get latitude => lat;
  double get longitude => lng;
}