// app_logger.dart
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

class EgyptianLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    output: _MultiOutput(),
  );

  // إيموجي مصري أصيل
  static final Map<Level, String> _emojis = {
    Level.verbose: 'معلومة',
    Level.debug: 'تجريب',
    Level.info: 'معلومة',
    Level.warning: 'تحذير',
    Level.error: 'خطأ',
    Level.wtf: 'كارثة',
  };

  // تسجيل عادي
  static void d(String message) => _logger.d('${_emojis[Level.debug]} $message');
  static void i(String message) => _logger.i('${_emojis[Level.info]} $message');
  static void w(String message) => _logger.w('${_emojis[Level.warning]} $message');
  static void e(String message, {dynamic error, StackTrace? stackTrace}) {
    _logger.e('${_emojis[Level.error]} $message', error: error, stackTrace: stackTrace);
    _reportToCrashlytics(message, error, stackTrace);
  }

  static void wtf(String message) {
    _logger.wtf('${_emojis[Level.wtf]} $message');
    _showDevNotification('التطبيق وقع!', message);
  }

  // فلسطين حرة
  static void palestine() {
    i('من النهر إلى البحر... فلسطين حرة');
  }

  // تسجيل الشبكة
  static Future<void> logNetwork() async {
    final connectivity = await Connectivity().checkConnectivity();
    i('الشبكة: ${connectivity.toString().split('.').last}');
  }

  // تسجيل الموقع
  static Future<void> logLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      d('الموقع: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      w('الموقع مش شغال');
    }
  }

  // أداء
  static void performance(String action, Duration duration) {
    i('$action استغرق ${duration.inMilliseconds} مللي ثانية');
  }

  // إبلاغ Crashlytics
  static void _reportToCrashlytics(String message, dynamic error, StackTrace? stackTrace) {
    FirebaseCrashlytics.instance.recordError(
      error ?? message,
      stackTrace,
      reason: message,
      fatal: false,
    );
  }

  // إشعار للمطور
  static Future<void> _showDevNotification(String title, String body) async {
    if (!kDebugMode) return;
    final notifications = FlutterLocalNotificationsPlugin();
    await notifications.show(
      999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('dev_channel', 'Dev Alerts'),
      ),
    );
  }
}

// إخراج متعدد
class _MultiOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (var line in event.lines) {
      debugPrint(line);
    }
    if (kReleaseMode) {
      // يمكن إرسال اللوج لـ Sentry أو Firebase
    }
  }
}
