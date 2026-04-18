import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart' show navigatorKey; // استيراد الـ key للتنقل

class FirebaseMessagingService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static ConfettiController? _confettiController;

  static bool _isInitialized = false;

  /// تهيئة كاملة
  static Future<void> initialize({
    ConfettiController? confettiController,
  }) async {
    if (_isInitialized) return;
    _confettiController = confettiController ?? ConfettiController();

    // طلب صلاحيات iOS
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
      provisional: false,
    );
    debugPrint('إذن الإشعارات: ${settings.authorizationStatus}');

    // تهيئة الإشعارات المحلية
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      requestCriticalPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // قنوات أندرويد
    await _createChannels();

    // معالجة الرسائل
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);
    // Note: background handler is registered once in `main.dart` to avoid
    // starting duplicate background isolates. Do not register it again here.

    // جلب التوكن
    final token = await _messaging.getToken();
    debugPrint('FCM Token: ${token?.substring(0, 50)}...');
    _saveToken(token);

    // الاشتراك في المواضيع العامة للإشعارات الحقيقية
    await _messaging.subscribeToTopic('general_updates');
    await _messaging.subscribeToTopic('bus_updates');
    debugPrint('تم الاشتراك في المواضيع: general_updates, bus_updates');

    _isInitialized = true;
  }

  /// إنشاء قنوات أندرويد
  static Future<void> _createChannels() async {
    final androidPlugin = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final channels = [
      AndroidNotificationChannel(
        'bus_arrival',
        'الحافلة وصلت',
        description: 'إشعارات وصول الحافلة',
        importance: Importance.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('bus_arrived'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
      ),
      AndroidNotificationChannel(
        'traffic_alert',
        'تحذير زحمة',
        description: 'إشعارات الزحمة والحوادث',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('general_ping'),
      ),
      AndroidNotificationChannel(
        'line_status',
        'حالة الخط',
        description: 'تحديثات حالة الخطوط',
        importance: Importance.defaultImportance,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('general_ping'),
      ),
      AndroidNotificationChannel(
        'offers',
        'عروض خاصة',
        description: 'عروض وتخفيضات',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('offer_alert'),
      ),
      AndroidNotificationChannel(
        'palestine',
        'فلسطين حرة',
        description: 'رسائل دعم فلسطين',
        importance: Importance.high,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('palestine_tribute'),
      ),
    ];

    for (var channel in channels) {
      await androidPlugin?.createNotificationChannel(channel);
    }
  }

  static AndroidNotificationChannel _channel(
    String id,
    String name,
    String description, {
    Importance importance = Importance.high,
    String? sound,
  }) {
    return AndroidNotificationChannel(
      id,
      name,
      description: description,
      importance: importance,
      playSound: sound != null,
      sound: sound != null
          ? RawResourceAndroidNotificationSound(sound.split('.').first)
          : const RawResourceAndroidNotificationSound('general_ping'),
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 1000, 500, 1000]),
    );
  }

  /// معالجة الرسائل في المقدمة
  static Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('إشعار في المقدمة: ${message.messageId}');

    final data = message.data;
    final notification = message.notification;

    // صوت وصول الحافلة
    if (data['type'] == 'bus_arrival') {
      await _audioPlayer.play(AssetSource('sounds/bus_arrived.mp3'));
      await Vibration.vibrate(pattern: [500, 500, 500, 1000]);
      _confettiController?.play();
    } else {
      // صوت عام لأي إشعارات أخرى في المقدمة
      await _audioPlayer.play(AssetSource('sounds/general_ping.mp3'));
    }

    if (notification != null) {
      await _showCustomNotification(message);
    }
  }

  /// إظهار إشعار مخصص
  static Future<void> _showCustomNotification(RemoteMessage message) async {
    final notification = message.notification!;
    final data = message.data;
    final type = data['type'] ?? 'default';

    final androidDetails = AndroidNotificationDetails(
      _getChannelId(type),
      _getChannelName(type),
      channelDescription: _getChannelDesc(type),
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: _getSound(type),
      enableVibration: true,
      vibrationPattern: _getVibrationPattern(type),
      icon: 'bus_icon', // الأيقونة الشفافة الاحترافية
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      styleInformation: const BigTextStyleInformation(''),
      ticker: notification.body,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'default',
    );

    await _notifications.show(
      notification.hashCode,
      await _getLocalizedTitle(notification.title ?? '', type),
      await _getLocalizedBody(notification.body ?? '', type),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: jsonEncode(data),
    );
  }

  static String _getChannelId(String type) {
    switch (type) {
      case 'bus_arrival':
        return 'bus_arrival';
      case 'traffic':
        return 'traffic_alert';
      case 'line_status':
        return 'line_status';
      case 'offer':
        return 'offers';
      case 'palestine':
        return 'palestine';
      default:
        return 'high_importance_channel';
    }
  }

  static String _getChannelName(String type) {
    switch (type) {
      case 'bus_arrival':
        return 'الحافلة وصلت';
      case 'traffic':
        return 'تحذير زحمة';
      case 'palestine':
        return 'فلسطين حرة';
      default:
        return 'إشعارات مهمة';
    }
  }

  static String _getChannelDesc(String type) {
    switch (type) {
      case 'bus_arrival':
        return 'إشعار لما الحافلة توصل محطتك';
      case 'palestine':
        return 'رسائل دعم فلسطين';
      default:
        return 'إشعارات مهمة من دليل حافلات إنجاز';
    }
  }

  static RawResourceAndroidNotificationSound? _getSound(String type) {
    switch (type) {
      case 'bus_arrival':
        return const RawResourceAndroidNotificationSound('bus_arrived');
      case 'offer':
        return const RawResourceAndroidNotificationSound('offer_alert');
      case 'palestine':
        return const RawResourceAndroidNotificationSound('palestine_tribute');
      default:
        return const RawResourceAndroidNotificationSound('general_ping');
    }
  }

  static Int64List _getVibrationPattern(String type) {
    switch (type) {
      case 'bus_arrival':
        return Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
      default:
        return Int64List.fromList([0, 500, 500, 500]);
    }
  }

  static Future<String> _getLocalizedTitle(String title, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    if (type == 'bus_arrival') return isEn ? 'Bus Arrived!' : 'الحافلة وصلت!';
    if (type == 'palestine') return isEn ? 'Free Palestine' : 'فلسطين حرة';
    return title;
  }

  static Future<String> _getLocalizedBody(String body, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    if (type == 'bus_arrival')
      return isEn
          ? 'The bus is at your stop now!'
          : 'يا وحش! الحافلة عند المحطة دلوقتي!';
    if (type == 'offer')
      return isEn
          ? 'Special offer: Free ride today!'
          : 'عرض النهاردة: ركوب مجاني!';
    if (type == 'palestine')
      return isEn
          ? 'From the river to the sea... Free Palestine'
          : 'من النهر إلى البحر... فلسطين حرة';
    return body;
  }

  /// عند الضغط على الإشعار
  static void _onNotificationTapped(NotificationResponse response) async {
    final payload = response.payload;
    if (payload == null) return;

    final data = jsonDecode(payload) as Map<String, dynamic>;
    final type = data['type'] ?? '';
    final lineNumber = data['line'] ?? '';

    if (type == 'bus_arrival' || lineNumber.isNotEmpty) {
      // الانتقال لصفحة تفاصيل الخط عند الضغط على الإشعار
      navigatorKey.currentState
          ?.pushNamed('/line_details', arguments: lineNumber);
    }

    debugPrint('تم الضغط على إشعار: $type - الخط $lineNumber');
  }

  /// معالجة الرسائل في الخلفية
  static Future<void> _handleMessageOpenedApp(RemoteMessage message) async {
    debugPrint('تم فتح التطبيق من إشعار: ${message.messageId}');
    // Navigate to specific screen
  }

  /// جلب التوكن
  static Future<String?> getToken() async {
    return await _messaging.getToken();
  }

  /// حفظ التوكن
  static Future<void> _saveToken(String? token) async {
    if (token == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fcm_token', token);
  }

  /// الاشتراك في موضوع
  static Future<void> subscribeToLine(String lineNumber) async {
    await _messaging.subscribeToTopic('line_$lineNumber');
    debugPrint('تم الاشتراك في الخط $lineNumber');
  }

  static Future<void> unsubscribeFromLine(String lineNumber) async {
    await _messaging.unsubscribeFromTopic('line_$lineNumber');
  }

  /// إشعار فلسطين
  static Future<void> sendPalestineNotification() async {
    await _showCustomNotification(
      RemoteMessage(
        notification: RemoteNotification(
          title: 'فلسطين حرة',
          body: 'من النهر إلى البحر... فلسطين حرة',
        ),
        data: {'type': 'palestine'},
        messageId: 'palestine_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
  }

  /// تفعيل الإشعارات الدفعية
  static Future<void> enablePushNotifications() async {
    try {
      // طلب صلاحيات
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // الاشتراك في مواضيع عامة
        await _messaging.subscribeToTopic('general_updates');
        await _messaging.subscribeToTopic('bus_updates');
        debugPrint('تم تفعيل الإشعارات الدفعية و الاشتراك في المواضيع');
      } else {
        debugPrint('لم يتم منح صلاحيات الإشعارات');
      }
    } catch (e) {
      debugPrint('خطأ في تفعيل الإشعارات الدفعية: $e');
    }
  }

  /// إلغاء تفعيل الإشعارات الدفعية
  static Future<void> disablePushNotifications() async {
    try {
      // إلغاء الاشتراك من المواضيع
      await _messaging.unsubscribeFromTopic('general_updates');
      await _messaging.unsubscribeFromTopic('bus_updates');
      debugPrint('تم إلغاء تفعيل الإشعارات الدفعية');
    } catch (e) {
      debugPrint('خطأ في إلغاء تفعيل الإشعارات الدفعية: $e');
    }
  }
}

// Background Handler removed - now handled only in main.dart to prevent duplicate engines
