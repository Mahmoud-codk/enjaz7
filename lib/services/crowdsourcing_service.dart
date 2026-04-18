import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class CrowdsourcingService {
  static final CrowdsourcingService _instance = CrowdsourcingService._internal();
  factory CrowdsourcingService() => _instance;
  CrowdsourcingService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _deviceId;

  Future<String> _getDeviceId() async {
    if (_deviceId != null) return _deviceId!;
    
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      _deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      _deviceId = iosInfo.identifierForVendor;
    } else {
      _deviceId = 'unknown_device_${DateTime.now().millisecondsSinceEpoch}';
    }
    return _deviceId!;
  }

  /// Updates the live location of a bus trip on Firestore
  Future<void> updateLiveLocation({
    required String routeNumber,
    required Position position,
    double? heading,
  }) async {
    try {
      final deviceId = await _getDeviceId();
      final docRef = _firestore
          .collection('bus_lines')
          .doc(routeNumber)
          .collection('active_trips')
          .doc(deviceId);

      await docRef.set({
        'current_location': GeoPoint(position.latitude, position.longitude),
        'last_updated': FieldValue.serverTimestamp(),
        'heading': heading ?? position.heading,
        'speed': position.speed,
        'is_active': true,
      }, SetOptions(merge: true));
      
      debugPrint('Live location updated for $routeNumber');
    } catch (e) {
      debugPrint('Error updating live location: $e');
    }
  }

  /// Marks a trip as inactive when the user stops navigating
  Future<void> stopTrip(String routeNumber) async {
    try {
      final deviceId = await _getDeviceId();
      await _firestore
          .collection('bus_lines')
          .doc(routeNumber)
          .collection('active_trips')
          .doc(deviceId)
          .update({'is_active': false});
    } catch (e) {
      debugPrint('Error stopping trip: $e');
    }
  }
}
