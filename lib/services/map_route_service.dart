import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../models/stop.dart';
import '../models/route_model.dart';

class MapRouteService {
  static final PolylinePoints _polylinePoints = PolylinePoints();

  /// Secure API Key from Remote Config
  static Future<String> _getApiKey() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate();
      return remoteConfig.getString('google_maps_api_key');
    } catch (e) {
      // Fallback to build-time env var
      return String.fromEnvironment('GOOGLE_MAPS_API_KEY', defaultValue: '');
    }
  }

  /// Draw route from current position to nearest stop (now async)
  Future<Set<Polyline>> drawRouteToNearestStop({
    required LatLng currentPosition,
    required Stop nearestStop,
  }) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      return {}; // No key, no route
    }

    final request = PolylineRequest(
      origin: PointLatLng(currentPosition.latitude, currentPosition.longitude),
      destination: PointLatLng(nearestStop.lat, nearestStop.lng),
      mode: TravelMode.driving,
    );

    final result = await _polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: request,
    );

    if (result.points.isNotEmpty) {
      List<LatLng> routePoints = result.points
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      return {
        Polyline(
          polylineId: const PolylineId('route_to_stop'),
          points: routePoints,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        ),
      };
    }
    return {};
  }

  /// Draw full route polyline using RouteModel points (no API call)
  Set<Polyline> drawRoutePolyline(RouteModel route) {
    final points = route.getAllPoints();
    if (points.length < 2) return {};

    return {
      Polyline(
        polylineId: PolylineId('full_route_${route.routeName}'),
        points: points.map((stop) => LatLng(stop.lat, stop.lng)).toList(),
        color: Colors.green,
        width: 8,
      ),
    };
  }

  /// Clear all route polylines
  void clearRoutes(Set<Polyline> polylines) {
    polylines.clear();
  }
}
