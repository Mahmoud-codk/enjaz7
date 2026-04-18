import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class CentralizedLocationService {
  static final CentralizedLocationService _instance = CentralizedLocationService._internal();
  factory CentralizedLocationService() => _instance;
  CentralizedLocationService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  final StreamController<Position> _positionController = StreamController<Position>.broadcast();
  bool _isMonitoring = false;
  Position? _lastPosition;

  Stream<Position> get positionStream => _positionController.stream;
  bool get isMonitoring => _isMonitoring;
  Position? get lastPosition => _lastPosition;

  Future<bool> _checkPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      return permission != LocationPermission.deniedForever;
    } catch (e) {
      debugPrint('Location permission check failed: $e');
      return false;
    }
  }

  Future<void> startMonitoring() async {
    if (_isMonitoring) return;

    if (!await _checkPermission()) {
      debugPrint('Location permission not granted');
      return;
    }

    _isMonitoring = true;

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 10, // Reduced frequency
      ),
    ).listen(
      (Position position) {
        _lastPosition = position;
        _positionController.add(position);
      },
      onError: (e) {
        debugPrint('Location stream error: $e');
        _isMonitoring = false;
      },
    );

    debugPrint('Centralized location monitoring started');
  }

  void stopMonitoring() {
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isMonitoring = false;
    debugPrint('Centralized location monitoring stopped');
  }

  Future<Position?> getCurrentPosition() async {
    if (!await _checkPermission()) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10), // Add timeout
        ),
      );
    } catch (e) {
      debugPrint('Failed to get current position: $e');
      return null;
    }
  }

  void dispose() {
    stopMonitoring();
    _positionController.close();
  }
}
