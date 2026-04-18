import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class DriverLocationService {
  Timer? _pollingTimer;

  // عدل هذا الرابط بعد أن ترفع السيرفر على Render
  static const String _defaultApiUrl =
      'https://enjaz7-server.onrender.com/api/driver-location';
  static const String _defaultJwtToken = 'Bearer YOUR_JWT_TOKEN';

  Future<Map<String, String>> _getApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiUrl': prefs.getString('api_url') ?? _defaultApiUrl,
      'jwtToken': prefs.getString('api_jwt_token') ?? _defaultJwtToken,
    };
  }

  Future<Map<String, dynamic>?> getDriverLocation(String driverId) async {
    final config = await _getApiConfig();
    final apiUrl = config['apiUrl']!;
    final jwtToken = config['jwtToken']!;

    if (driverId.trim().isEmpty) {
      debugPrint(
          '⚠️ DriverLocationService: driverId is empty. Skipping request.');
      return null;
    }

    final uri = Uri.parse('$apiUrl/$driverId');
    debugPrint('📡 Requesting Driver Location from: $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': jwtToken,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final jsonData = jsonDecode(response.body);
        if (jsonData is Map<String, dynamic>) {
          return jsonData;
        }
      } else {
        if (response.statusCode == 401) {
          debugPrint(
              '⚠️ خطأ في المصادقة: التوكن المستخدم غير صالح. تأكد من إعدادات السيرفر أو تسجيل الدخول.');
        } else {
          debugPrint(
              'Driver location API status: ${response.statusCode}, body: ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('Error fetching driver location from API: $e');
    }

    return null;
  }

  void listenToDriverLocation(
      String driverId, Function(Map<String, dynamic>?) onLocationUpdate,
      {Duration interval = const Duration(seconds: 5)}) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(interval, (_) async {
      final data = await getDriverLocation(driverId);
      onLocationUpdate(data);
    });
  }

  void stopListening() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }
}
