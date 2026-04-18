import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'station_translation_service.dart';
import '../models/stop.dart';

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(MyForegroundTaskHandler());
}

class MyForegroundTaskHandler extends TaskHandler {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static bool _localNotificationsInitialized = false;

  final Set<String> notified400m = {};
  final Set<String> notified50m = {};

  Position? _lastPosition;
  bool _flagsLoaded = false;
  DateTime? _lastPositionTimestamp;
  Position? _lastUploadedPosition; // لتتبع آخر موقع تم رفعه
  double _averageSpeedMps = 0.0; // متر/ثانية
  double _currentBearing = 0.0;
  bool _voiceAlertsEnabled = true;
  String _langCode = 'ar';

  static const double _minSpeedToCalculateEta = 0.6; // 2.16 كم/س
  static const double _maxValidSpeed =
      40.0; // حوالي 144 كم/س (لإقصاء القفزات الغريبة)

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _voiceAlertsEnabled = prefs.getBool('voice_alerts_enabled') ?? true;
    final lang = prefs.getString('language') ?? 'العربية';
    _langCode = (lang == 'English') ? 'en' : 'ar';
  }

  Future<void> _initLocalNotifications() async {
    if (_localNotificationsInitialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );

    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    _localNotificationsInitialized = true;
  }

  Future<void> _showLocalNotification(String title, String body) async {
    await _localNotifications.show(
      0,
      title,
      body,
      NotificationDetails(
        android: const AndroidNotificationDetails(
          'station_channel',
          'Station Alerts',
          channelDescription: 'تنبيهات اقتراب المحطات',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _speak(String text) async {
    if (kIsWeb || !_voiceAlertsEnabled) return;
    try {
      await _tts.setLanguage(_langCode == 'en' ? 'en-US' : 'ar-SA');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (e) {
      debugPrint('TTS error: $e, playing fallback sound');
      await _playFallbackAlertSound();
    }
  }

  Future<void> _playFallbackAlertSound() async {
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notificationEvent,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );
      await _audioPlayer.play(AssetSource('sounds/arrival.mp3'));
    } catch (e) {
      debugPrint('Fallback sound error: $e');
    }
  }

  void _updateSpeed(Position current) {
    final now = DateTime.now();

    if (_lastPosition != null && _lastPositionTimestamp != null) {
      final distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        current.latitude,
        current.longitude,
      );
      final timeDiffSec =
          now.difference(_lastPositionTimestamp!).inMilliseconds / 1000;

      if (timeDiffSec > 0) {
        final candidateSpeed = distance / timeDiffSec;

        if (candidateSpeed >= 0 && candidateSpeed < _maxValidSpeed) {
          if (_averageSpeedMps == 0) {
            _averageSpeedMps = candidateSpeed;
          } else {
            _averageSpeedMps = _averageSpeedMps * 0.7 + candidateSpeed * 0.3;
          }
        }
      }

      // Update bearing
      _currentBearing = _calculateBearing(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        current.latitude,
        current.longitude,
      );
    }

    _lastPosition = current;
    _lastPositionTimestamp = now;
  }

  String _formatEta(Duration duration) {
    if (duration.inSeconds < 0) {
      return _langCode == 'en' ? 'N/A' : 'غير متاح';
    }

    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return _langCode == 'en'
          ? '$minutes m $seconds s'
          : '$minutes د $seconds ث';
    }
    return _langCode == 'en' ? '$seconds s' : '$seconds ث';
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * (pi / 180.0);
    final lat1Rad = lat1 * (pi / 180.0);
    final lat2Rad = lat2 * (pi / 180.0);

    final x = sin(dLon) * cos(lat2Rad);
    final y =
        cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon);

    final bearing = atan2(x, y);
    return (bearing * 180.0 / pi + 360) % 360;
  }

  Stop? _findNextStop(
      List<Stop> stops, Position currentPosition, double currentBearing) {
    Stop? nextStop;
    double minAngleDiff = double.infinity;

    for (Stop stop in stops) {
      final stopBearing = _calculateBearing(
        currentPosition.latitude,
        currentPosition.longitude,
        stop.lat,
        stop.lng,
      );

      final angleDiff = (stopBearing - currentBearing).abs();
      final normalizedDiff = angleDiff > 180 ? 360 - angleDiff : angleDiff;

      if (normalizedDiff < minAngleDiff && normalizedDiff < 45) {
        // within 45 degrees
        minAngleDiff = normalizedDiff;
        nextStop = stop;
      }
    }

    return nextStop;
  }

  Future<void> _sendLocationToServer(Position position, double speedMps,
      Stop? nearestStop, String? etaText, Stop? nextStop) async {
    try {
      final config = await _getApiConfig();
      final apiUrl = config['apiUrl']!;
      final jwtToken = config['jwtToken']!;
      final driverId = config['driverId']!;

      final uri = Uri.parse('$apiUrl/$driverId');
      final payload = {
        'driver_id': driverId,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'speed_mps': speedMps,
        'nearest_stop':
            nearestStop?.name ?? (_langCode == 'en' ? 'Unknown' : 'غير محدد'),
        'eta_to_nearest': etaText ?? (_langCode == 'en' ? 'N/A' : 'غير متاح'),
        'next_stop':
            nextStop?.name ?? (_langCode == 'en' ? 'Unknown' : 'غير محدد'),
        'accuracy': position.accuracy,
        'timestamp': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await http
          .post(
            uri,
            headers: {
              'Authorization': jwtToken,
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(
            const Duration(seconds: 8),
            onTimeout: () => http.Response('{"error": "Timeout"}', 408),
          );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint(
            'Location sent to API: ${position.latitude}, ${position.longitude}');
      } else {
        debugPrint(
            'Failed sending location to API status=${response.statusCode} body=${response.body}');
      }
    } catch (e) {
      debugPrint('Error sending location to API: $e');
    }
  }

  Future<void> _loadNotifiedFlags(SharedPreferences prefs) async {
    // Load persistent notified flags
    notified400m.clear();
    notified50m.clear();
    final allKeys = prefs.getKeys();
    for (String key in allKeys) {
      if (key.startsWith('notified_400m_')) {
        if (prefs.getBool(key) == true) {
          notified400m.add(key.substring('notified_400m_'.length));
        }
      } else if (key.startsWith('notified_50m_')) {
        if (prefs.getBool(key) == true) {
          notified50m.add(key.substring('notified_50m_'.length));
        }
      }
    }
    _flagsLoaded = true;
  }

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static final FlutterTts _tts = FlutterTts();

  static const String _defaultApiUrl =
      'https://example.com/api/driver-location';
  static const String _defaultJwtToken = 'Bearer YOUR_JWT_TOKEN';

  Future<Map<String, String>> _getApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiUrl': prefs.getString('api_url') ?? _defaultApiUrl,
      'jwtToken': prefs.getString('api_jwt_token') ?? _defaultJwtToken,
      'driverId': prefs.getString('driver_id') ?? 'driver_1',
    };
  }

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    debugPrint('Foreground task started');
    // Load persistent flags on start
    final prefs = await SharedPreferences.getInstance();
    await _loadNotifiedFlags(prefs);
    await _loadPreferences();

    // Init Flutter local notifications once
    await _initLocalNotifications();

    // Init TTS settings
    if (!kIsWeb) {
      try {
        await _tts.setLanguage('ar-SA');
        await _tts.setSpeechRate(0.45);
        await _tts.setPitch(1.0);
      } catch (e) {
        debugPrint('TTS init failed: $e');
      }
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    onEvent(timestamp);
  }

  Future<void> onEvent(DateTime timestamp) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // زيادة طفيفة لتقليل استهلاك البطارية
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      if (!_flagsLoaded) {
        await _loadNotifiedFlags(prefs);
      }

      final stopsString = prefs.getString('monitoring_stops') ?? '';

      final List<Stop> stops = stopsString.isEmpty
          ? []
          : stopsString.split(',').map((s) {
              final parts = s.split(':');
              return Stop(
                name: parts[0],
                lat: double.tryParse(parts[1]) ?? 0.0,
                lng: double.tryParse(parts[2]) ?? 0.0,
              );
            }).toList();

      // Smart notifications and nearest stop
      Stop? nearestStop;
      double minDistance = double.infinity;
      final List<Map<String, dynamic>> nearbyStops = [];

      _updateSpeed(position);

      final monitoringLineId = prefs.getString('monitoring_line_id');
      final monitoringTripId = prefs.getString('monitoring_trip_id');

      // حساب المسافة عن آخر رفع لتقليل استهلاك البيانات والبطارية
      double distanceMoved = _lastUploadedPosition != null
          ? Geolocator.distanceBetween(position.latitude, position.longitude,
              _lastUploadedPosition!.latitude, _lastUploadedPosition!.longitude)
          : 999.0;

      if (kDebugMode) {
        debugPrint(
            '📍 مراقبة الموقع: ${position.latitude}, ${position.longitude} | عدد المحطات المراقبة: ${stops.length}');
      }

      if (monitoringLineId != null &&
          monitoringTripId != null &&
          _averageSpeedMps >= 1.5 &&
          distanceMoved > 10) {
        // ارفع الموقع فقط إذا تحرك الباص أكثر من 10 أمتار
        // ~5.4 km/h
        FlutterForegroundTask.sendDataToMain({
          'action': 'crowdsource_update',
          'line_id': monitoringLineId,
          'trip_id': monitoringTripId,
          'lat': position.latitude,
          'lng': position.longitude,
          'speed': _averageSpeedMps,
          'heading': _currentBearing,
        });
        _lastUploadedPosition = position;
      }

      for (Stop stop in stops) {
        double distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stop.lat,
          stop.lng,
        );

        // 🔔 تنبيه الاقتراب (400 متر - مرة واحدة لكل محطة)
        if (distance <= 400 && !notified400m.contains(stop.name)) {
          notified400m.add(stop.name);
          await prefs.setBool('notified_400m_${stop.name}', true);

          final String translatedStopName = _langCode == 'en'
              ? StationTranslationService().translate(stop.name)
              : stop.name;

          debugPrint(
              '🔔 تنبيه: اقتراب من محطة ${stop.name} (المسافة: ${distance.toInt()}م)');

          final title = _langCode == 'en'
              ? '🚌 Approaching Station'
              : '🚍 اقتراب من محطة';
          final body = _langCode == 'en'
              ? 'Bus is ${distance.toInt()}m away from $translatedStopName'
              : 'الباص على بعد ${distance.toInt()} متر من ${stop.name}';

          FlutterForegroundTask.updateService(
            notificationTitle: title,
            notificationText: body,
          );

          await _showLocalNotification(title, body);

          if (await Vibration.hasVibrator()) {
            Vibration.vibrate(duration: 800);
          }

          await _speak(body);

          _analytics.logEvent(
            name: 'approach_stop',
            parameters: {
              'stop_name': stop.name,
              'distance': distance.toStringAsFixed(0)
            },
          );
        }

        // 🔥 تنبيه الوصول (50 متر - مرة واحدة لكل محطة)
        if (distance <= 50 && !notified50m.contains(stop.name)) {
          notified50m.add(stop.name);
          await prefs.setBool('notified_50m_${stop.name}', true);

          final String translatedStop = _langCode == 'en'
              ? StationTranslationService().translate(stop.name)
              : stop.name;

          debugPrint('📍 تنبيه: وصلنا محطة ${stop.name}!');
          FlutterForegroundTask.updateService(
            notificationTitle:
                _langCode == 'en' ? '📍 Arrived at Station' : '📍 وصلت للمحطة',
            notificationText: translatedStop,
          );

          Vibration.vibrate(pattern: [0, 400, 200, 400]);
          await _audioPlayer.setAudioContext(
            AudioContext(
              android: AudioContextAndroid(
                isSpeakerphoneOn: true,
                stayAwake: true,
                contentType: AndroidContentType.sonification,
                usageType: AndroidUsageType.notificationEvent,
                audioFocus: AndroidAudioFocus.gain,
              ),
            ),
          );
          await _audioPlayer.play(AssetSource('sounds/arrival.mp3'));
          await _speak(_langCode == 'en'
              ? 'Arrived at $translatedStop station. Please prepare to get off.'
              : 'وصلت إلى محطة ${stop.name}. يرجى الاستعداد للنزول.');

          _analytics.logEvent(
            name: 'arrived_stop',
            parameters: {'stop_name': stop.name},
          );
        }

        if (distance <= 400) {
          nearbyStops.add({
            'name': stop.name,
            'distance': distance,
          });
        }

        // Reset station flags after passing marker by buffer
        if (distance > 500 && notified400m.contains(stop.name)) {
          notified400m.remove(stop.name);
          await prefs.remove('notified_400m_${stop.name}');
        }
        if (distance > 80 && notified50m.contains(stop.name)) {
          notified50m.remove(stop.name);
          await prefs.remove('notified_50m_${stop.name}');
        }

        // 🧠 Nearest stop prediction
        if (distance < minDistance) {
          minDistance = distance;
          nearestStop = stop;
        }
      }

      Stop? nextStop;
      if (_averageSpeedMps >= _minSpeedToCalculateEta) {
        nextStop = _findNextStop(stops, position, _currentBearing);
      }

      // Log nearest stop + ETA
      if (nearestStop != null) {
        final String translatedNearest = _langCode == 'en'
            ? StationTranslationService().translate(nearestStop.name)
            : nearestStop.name;

        String nearestHint = _langCode == 'en'
            ? '🧠 Nearest stop: $translatedNearest (${minDistance.toStringAsFixed(0)}m)'
            : '🧠 أقرب محطة: ${nearestStop.name} (${minDistance.toStringAsFixed(0)}م)';

        Duration? etaDuration;
        if (_averageSpeedMps >= _minSpeedToCalculateEta) {
          final etaSeconds = (minDistance / _averageSpeedMps).round();
          etaDuration = Duration(seconds: etaSeconds);
          nearestHint += ' - ETA ${_formatEta(etaDuration)}';
        } else {
          nearestHint += ' - ETA غير متاح (السرعة قليلة)';
        }

        debugPrint(nearestHint);

        await prefs.setString('nearest_stop_name', translatedNearest);
        await prefs.setDouble('nearest_stop_distance', minDistance);
        await prefs.setDouble('nearest_stop_speed_mps', _averageSpeedMps);
        if (etaDuration != null) {
          await prefs.setInt('nearest_stop_eta_seconds', etaDuration.inSeconds);
          await prefs.setString(
              'nearest_stop_eta_text', _formatEta(etaDuration));
        }

        if (nextStop != null) {
          await prefs.setString('next_stop_name', nextStop.name);
        } else {
          await prefs.remove('next_stop_name');
        }

        // Send location to external API
        await _sendLocationToServer(
            position,
            _averageSpeedMps,
            nearestStop,
            etaDuration != null ? _formatEta(etaDuration) : 'غير متاح',
            nextStop);

        // Update foreground notification once with ETA and nearest stop info
        final serviceText = _langCode == 'en'
            ? (etaDuration != null
                ? 'Nearest: $translatedNearest - ETA ${_formatEta(etaDuration)}'
                : 'Nearest: $translatedNearest - Calculating ETA...')
            : (etaDuration != null
                ? 'أقرب محطة ${nearestStop.name} - ETA ${_formatEta(etaDuration)}'
                : 'أقرب محطة ${nearestStop.name} - تحديد ETA...');

        FlutterForegroundTask.updateService(
          notificationTitle: _langCode == 'en'
              ? 'Monitoring Nearest Station'
              : 'مراقبة المحطة الأقرب',
          notificationText: serviceText,
        );
      } else {
        await prefs.remove('nearest_stop_name');
        await prefs.remove('nearest_stop_distance');
        await prefs.remove('nearest_stop_eta_seconds');
        await prefs.remove('nearest_stop_eta_text');

        // Send location to external API even if no nearest stop
        await _sendLocationToServer(
            position, _averageSpeedMps, null, null, null);
      }

      if (nearbyStops.isNotEmpty) {
        debugPrint(
          'Nearby stops: ${nearbyStops.map((s) => s['name']).toList()}',
        );
      }
    } catch (e) {
      debugPrint('Location task error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool sticky) async {
    debugPrint('Foreground task destroyed');
  }
}

class UltimateLocationNotificationService {
  List<Stop> stops;
  String? targetDestination;
  String? lineId;
  bool _isMonitoring = false;

  bool get isMonitoring => _isMonitoring;

  // دالة ثابتة لضمان الوصول لنفس الـ "Room" من جانب السائق والراكب
  static DocumentReference getTripRoom(String lineId, String tripId) {
    return FirebaseFirestore.instance
        .collection('bus_lines')
        .doc(lineId)
        .collection('active_trips')
        .doc(tripId);
  }

  UltimateLocationNotificationService({
    required this.stops,
    this.targetDestination,
    this.lineId,
  });

  Future<void> initialize() async {
    bool isServiceRunning = false;
    try {
      isServiceRunning = await FlutterForegroundTask.isRunningService;
    } catch (e) {
      debugPrint('Foreground task plugin unavailable: $e');
    }

    if (isServiceRunning) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();

    // إصلاح: لا تمسح المحطات القديمة إذا كانت القائمة الجديدة فارغة (مهم عند استعادة الحالة)
    if (stops.isNotEmpty) {
      await prefs.setString(
        'monitoring_stops',
        stops.map((s) => '${s.name}:${s.lat}:${s.lng}').join(','),
      );
    }

    if (targetDestination != null) {
      await prefs.setString('target_destination', targetDestination!);
    }

    try {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'location_service',
          channelName: 'Location Monitoring',
          channelDescription: 'Monitoring proximity to bus stops',
          channelImportance:
              NotificationChannelImportance.MAX, // لضمان التنبيه الصوتي الملح
          priority: NotificationPriority.LOW,
        ),
        iosNotificationOptions: IOSNotificationOptions(
          showNotification: true,
          playSound: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.repeat(5000), // كل 5 ثواني
          autoRunOnBoot: true,
          allowWakeLock: true,
          allowWifiLock: true,
        ),
      );
    } catch (e) {
      debugPrint('Foreground task init failed: $e');
    }

    // ignore: invalid_use_of_visible_for_testing_member
    FlutterForegroundTask.receivePort?.listen((message) {
      if (message is Map && message['action'] == 'crowdsource_update') {
        final rLineId = message['line_id'];
        final rTripId = message['trip_id'];
        if (rLineId != null && rTripId != null) {
          getTripRoom(rLineId, rTripId).set({
            'current_location': GeoPoint(message['lat'], message['lng']),
            'speed': message['speed'],
            'heading': message['heading'],
            'last_updated': FieldValue.serverTimestamp(),
            'is_crowdsourced': true,
          }, SetOptions(merge: true)).catchError((e) {
            debugPrint('Failed to update crowdsourced location: $e');
          });
        }
      }
    });
  }

  Future<void> startMonitoring({String? destination, String? lineId}) async {
    if (_isMonitoring) return;

    targetDestination = destination ?? targetDestination;
    this.lineId = lineId ?? this.lineId;

    if (this.lineId != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('monitoring_line_id', this.lineId!);

      final tripId =
          '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(10000)}';
      await prefs.setString('monitoring_trip_id', tripId);
    }

    await initialize();

    final prefs = await SharedPreferences.getInstance();
    final isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    String notificationText = (targetDestination ?? '').isNotEmpty
        ? (isEn
            ? 'Alert when approaching $targetDestination'
            : 'تنبيه عند الاقتراب من $targetDestination')
        : (isEn ? 'Monitoring nearby stations' : 'مراقبة المحطات القريبة');

    // Request necessary permissions before starting service
    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }
    if (await Permission.locationAlways.isDenied) {
      await Permission.locationAlways.request();
    }

    try {
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    } catch (e) {
      debugPrint('Error requesting battery optimization: $e');
    }

    await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: isEn ? 'Station Monitoring' : 'مراقبة المحطات',
      notificationText: notificationText,
      callback: startCallback,
    );

    _isMonitoring = true;
  }

  Future<void> refreshStops(List<Stop> newStops) async {
    stops.clear();
    stops.addAll(newStops);

    if (_isMonitoring) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'monitoring_stops',
        stops.map((s) => '${s.name}:${s.lat}:${s.lng}').join(','),
      );
    }
  }

  Future<void> startMonitoringForDestination(String destination,
      {String? lineId}) async {
    return startMonitoring(destination: destination, lineId: lineId);
  }

  Future<void> stopMonitoring() async {
    if (!_isMonitoring) return;

    await FlutterForegroundTask.stopService();
    _isMonitoring = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('monitoring_stops');
    await prefs.remove('target_destination');
    await prefs.remove('monitoring_line_id');
    await prefs.remove('monitoring_trip_id');
  }
}
