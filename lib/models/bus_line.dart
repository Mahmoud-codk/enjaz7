import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/stop.dart';
import '../services/geocoding_service.dart';
import '../services/station_translation_service.dart';

part 'bus_line.g.dart';

@HiveType(typeId: 1)
class BusLine {
  @HiveField(0)
  final String routeNumber;
  @HiveField(1)
  final String type;
  @HiveField(2)
  final List<String> stops;
  @HiveField(3)
  final int emptySeats;
  @HiveField(4)
  DateTime? lastUsed;
  @HiveField(5)
  int? usageCount;

  BusLine({
    required this.routeNumber,
    required this.type,
    required this.stops,
    required this.emptySeats,
    this.lastUsed,
    this.usageCount,
  });

  /// جلب المحطات مترجمة
  List<String> getLocalizedStops(Locale locale) {
    if (locale.languageCode == 'en') {
      return stops
          .map((s) => StationTranslationService().translate(s))
          .toList();
    }
    return stops;
  }

  /// جلب نوع الخط مترجم
  String getLocalizedType(Locale locale) {
    if (locale.languageCode == 'en') {
      return type == 'اتوبيس' ? 'Bus' : 'Mini Bus';
    }
    return type;
  }

  /// اتجاه الخط مترجم
  String getLocalizedDirection(Locale locale) {
    if (stops.isEmpty)
      return locale.languageCode == 'en' ? 'Unknown' : 'غير معروف';
    final localizedStops = getLocalizedStops(locale);
    if (localizedStops.length == 1) return localizedStops.first;
    return '${localizedStops.first} - ${localizedStops.last}';
  }

  // تحسين: تأكد إن القوائم مش null أبدًا
  factory BusLine.fromMap(Map<String, dynamic> map) {
    return BusLine(
      routeNumber: map['routeNumber']?.toString() ?? '',
      type: map['type']?.toString() ?? '',
      stops: _parseStops(map['stops']),
      emptySeats: map['emptySeats'] != null
          ? int.tryParse(map['emptySeats'].toString()) ?? 0
          : 0,
      lastUsed:
          map['lastUsed'] != null ? DateTime.tryParse(map['lastUsed']) : null,
      usageCount: map['usageCount'] != null
          ? int.tryParse(map['usageCount'].toString())
          : null,
    );
  }

  static List<String> _parseStops(dynamic stops) {
    if (stops == null) return [];
    if (stops is List) {
      return stops
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (stops is String) {
      return stops
          .split(RegExp(r'[،,.]')) // Added Arabic comma
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return [];
  }

  Map<String, dynamic> toMap() {
    return {
      'routeNumber': routeNumber,
      'type': type,
      'stops': stops, // لو عايز تخزنها كـ String: stops.join(',')
      'emptySeats': emptySeats,
      'lastUsed': lastUsed?.toIso8601String(),
      'usageCount': usageCount,
    };
  }

  BusLine copyWith({
    String? routeNumber,
    String? type,
    List<String>? stops,
    int? emptySeats,
    DateTime? lastUsed,
    int? usageCount,
  }) {
    return BusLine(
      routeNumber: routeNumber ?? this.routeNumber,
      type: type ?? this.type,
      stops: stops ?? this.stops,
      emptySeats: emptySeats ?? this.emptySeats,
      lastUsed: lastUsed ?? this.lastUsed,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  @override
  String toString() {
    return 'BusLine(routeNumber: $routeNumber, type: $type, stops: $stops, emptySeats: $emptySeats)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BusLine &&
        other.routeNumber == routeNumber &&
        other.type == type &&
        _listEquals(other.stops, stops) &&
        other.emptySeats == emptySeats;
  }

  // أحسن طريقة لمقارنة القوائم في Dart
  static bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null || b == null) return a == b;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    return Object.hash(routeNumber, type, Object.hashAll(stops), emptySeats);
    // Object.hashAll أفضل من XOR للقوائم
  }

  /// جلب المحطات مع الإحداثيات
  Future<List<Stop>> getStopsWithCoordinates() async {
    return await UltimateGeocodingService.smartGeocodeMultiple(stops,
        routeNumber: routeNumber);
  }

  /// اتجاه الخط (من أول محطة لآخر محطة)
  String get direction {
    if (stops.isEmpty) return 'غير معروف';
    if (stops.length == 1) return stops.first;
    return '${stops.first} - ${stops.last}';
  }

  /// التحقق من صحة المسار (بداية ونهاية)
  Future<bool> hasValidRouteCoordinates() async {
    final firstStop = await getFirstValidStop();
    final lastStop = await getLastValidStop();

    if (firstStop == null || lastStop == null) return false;

    final validFirst = UltimateGeocodingService.areCoordinatesValid(
        firstStop.lat, firstStop.lng);
    final validLast = UltimateGeocodingService.areCoordinatesValid(
        lastStop.lat, lastStop.lng);
    final different =
        (firstStop.lat != lastStop.lat || firstStop.lng != lastStop.lng);

    return validFirst && validLast && different;
  }

  /// أول محطة لها إحداثيات صحيحة
  Future<Stop?> getFirstValidStop() async {
    final stopsWithCoords = await getStopsWithCoordinates();
    try {
      return stopsWithCoords.firstWhere(
        (stop) =>
            UltimateGeocodingService.areCoordinatesValid(stop.lat, stop.lng),
      );
    } catch (_) {
      return null; // لو مفيش أي محطة صالحة
    }
  }

  /// آخر محطة لها إحداثيات صحيحة
  Future<Stop?> getLastValidStop() async {
    final stopsWithCoords = await getStopsWithCoordinates();
    for (int i = stopsWithCoords.length - 1; i >= 0; i--) {
      final stop = stopsWithCoords[i];
      if (UltimateGeocodingService.areCoordinatesValid(stop.lat, stop.lng)) {
        return stop;
      }
    }
    return null;
  }

  /// كل المحطات اللي لها إحداثيات صحيحة
  Future<List<Stop>> getAllValidStops() async {
    final stopsWithCoords = await getStopsWithCoordinates();
    return stopsWithCoords
        .where((stop) =>
            UltimateGeocodingService.areCoordinatesValid(stop.lat, stop.lng))
        .toList();
  }
}
