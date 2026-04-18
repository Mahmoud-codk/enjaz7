import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:confetti/confetti.dart';
import '../models/stop.dart';

class UltimateMapService {
  static const double _pulseRadius = 100;

  // أيقونات مصرية أصيلة
  static Future<BitmapDescriptor> busIcon() => BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/bus.png',
      );

  static Future<BitmapDescriptor> metroIcon() => BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/icons/metro.png',
      );

  static Future<BitmapDescriptor> microbusIcon() => BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(40, 40)),
        'assets/icons/microbus.png',
      );

  static Future<BitmapDescriptor> tukTukIcon() => BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(36, 36)),
        'assets/icons/tuktuk.png',
      );

  static Future<BitmapDescriptor> palestineIcon() => BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(64, 64)),
        'assets/icons/palestine.png',
      );

  // ألوان الخطوط الرسمية
  static const Map<String, Color> lineColors = {
    '105': Color(0xFFE53935), // أحمر
    '777': Color(0xFF3949AB), // أزرق غامق
    '500': Color(0xFF43A047), // أخضر
    '8': Color(0xFFFFB300),   // أصفر
    'M1': Color(0xFFD81B60),  // وردي
    'M2': Color(0xFF8E24AA),  // بنفسجي
    'M3': Color(0xFF039BE5),  // سماوي
  };

  // إنشاء Marker مع نبض
  static Marker pulsingMarker({
    required String id,
    required LatLng position,
    required String title,
    String? snippet,
    BitmapDescriptor? icon,
    bool pulse = false,
    ConfettiController? confettiController,
  }) {
    return Marker(
      markerId: MarkerId(id),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: snippet,
      ),
      icon: icon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      onTap: pulse
          ? () {
              confettiController?.play();
              // يمكن تشغيل Lottie هنا
            }
          : null,
    );
  }

  // إنشاء Polyline متحرك
  static Polyline animatedPolyline({
    required String id,
    required List<LatLng> points,
    Color color = const Color(0xFF2196F3),
    int width = 6,
    bool showAnimation = true,
  }) {
    return Polyline(
      polylineId: PolylineId(id),
      points: points,
      color: color,
      width: width,
      geodesic: true,
      patterns: showAnimation ? [PatternItem.dash(20), PatternItem.gap(10)] : [],
      jointType: JointType.round,
      endCap: Cap.roundCap,
      startCap: Cap.roundCap,
    );
  }

  // إنشاء دائرة حول المحطة القريبة
  static Set<Circle> proximityCircles({
    required LatLng userLocation,
    required List<Stop> nearbyStops,
    Color color = Colors.red,
  }) {
    final circles = <Circle>{};
    for (var stop in nearbyStops) {
      final distance = _calculateDistance(userLocation, LatLng(stop.lat, stop.lng));
      if (distance <= 500) {
        circles.add(
          Circle(
            circleId: CircleId('proximity_${stop.name}'),
            center: LatLng(stop.lat, stop.lng),
            radius: 100,
            fillColor: color.withValues(alpha: 0.2),
            strokeColor: color,
            strokeWidth: 3,
          ),
        );
      }
    }
    return circles;
  }

  // رسم المسار كامل مع Markers و Polyline
  static Future<Map<String, dynamic>> createFullRoute({
    required List<LatLng> points,
    required List<String> stopNames,
    required String lineNumber,
    ConfettiController? confettiController,
    bool showPulse = true,
  }) async {
    final markers = <Marker>{};
    final polylines = <Polyline>{};
    final circles = <Circle>{};

    final color = lineColors[lineNumber] ?? Colors.blue;

    // Polyline متحرك
    polylines.add(animatedPolyline(
      id: 'route_$lineNumber',
      points: points,
      color: color,
    ));

    // Markers للمحطات
    for (int i = 0; i < points.length; i++) {
      final isStart = i == 0;
      final isEnd = i == points.length - 1;
      final stopName = stopNames.length > i ? stopNames[i] : 'محطة ${i + 1}';

      BitmapDescriptor? icon;
      if (isStart) icon = await busIcon();
      if (isEnd) icon = await metroIcon();

      markers.add(pulsingMarker(
        id: 'stop_$i',
        position: points[i],
        title: stopName,
        snippet: isStart
            ? 'نقطة البداية'
            : isEnd
                ? 'نقطة النهاية - وصلت!'
                : 'محطة وسيطة',
        icon: icon,
        pulse: isEnd,
        confettiController: isEnd ? confettiController : null,
      ));

      // دائرة نبض عند الوصول
      if (isEnd) {
        circles.add(Circle(
          circleId: CircleId('arrival_pulse'),
          center: points[i],
          radius: _pulseRadius,
          fillColor: Colors.green.withValues(alpha: 0.3),
          strokeColor: Colors.green,
          strokeWidth: 4,
        ));
      }
    }

    return {
      'markers': markers,
      'polylines': polylines,
      'circles': circles,
      'bounds': calculateBounds(points),
    };
  }

  // حساب Bounds مع Padding
  static LatLngBounds calculateBounds(List<LatLng> points, {double padding = 0.005}) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(30.0, 31.2),
        northeast: const LatLng(30.1, 31.3),
      );
    }

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }

    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  // حساب المسافة
  static double _calculateDistance(LatLng a, LatLng b) {
    const R = 6371000; // متر
    final dLat = _degToRad(b.latitude - a.latitude);
    final dLng = _degToRad(b.longitude - a.longitude);
    final h = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degToRad(a.latitude)) * cos(_degToRad(b.latitude)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return R * c;
  }

  static double _degToRad(double deg) => deg * pi / 180;

  // إضافة علم فلسطين
  static Future<Marker> palestineMarker() async {
    return Marker(
      markerId: const MarkerId('palestine_forever'),
      position: const LatLng(31.9474, 35.2272),
      icon: await palestineIcon(),
      infoWindow: const InfoWindow(
        title: 'فلسطين حرة',
        snippet: 'من النهر إلى البحر... فلسطين حرة',
      ),
    );
  }

  // وضع ليلي
  static MapType getMapType(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.dark ? MapType.normal : MapType.normal;
  }

  // إظهار الزحمة
  static Color getTrafficColor(double speed) {
    if (speed > 40) return Colors.green;
    if (speed > 20) return Colors.orange;
    return Colors.red;
  }
}