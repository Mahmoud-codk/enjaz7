import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:share_plus/share_plus.dart';
import 'package:clipboard/clipboard.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:app_settings/app_settings.dart';
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/firebase_messaging_service.dart';

class UltimateTestScreen extends StatefulWidget {
  const UltimateTestScreen({super.key});

  @override
  State<UltimateTestScreen> createState() => _UltimateTestScreenState();
}

class _UltimateTestScreenState extends State<UltimateTestScreen>
    with TickerProviderStateMixin {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final GoogleSignIn _googleSignIn = GoogleSignIn.standard();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // final FirebaseMessagingService _fcmService = FirebaseMessagingService();

  late ConfettiController _confettiController;
  String _connectionStatus = 'جاري التحقق...';
  String _fcmToken = 'غير متوفر';
  String _userId = 'غير مسجل';
  bool _isDevMode = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _initializeNotifications();
    _checkConnection();
    _getFCMToken();
    _getCurrentUser();
  }

  Future<void> _initializeNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  Future<void> _checkConnection() async {
    final result = await Connectivity().checkConnectivity();
    setState(() {
      _connectionStatus =
          result.contains(ConnectivityResult.none) ? 'لا يوجد إنترنت' : 'متصل';
    });
  }

  Future<void> _getFCMToken() async {
    final token = await FirebaseMessagingService.getToken();
    setState(() => _fcmToken = token?.substring(0, 50) ?? 'فشل');
  }

  void _getCurrentUser() {
    final user = _auth.currentUser;
    setState(() => _userId = user?.uid ?? 'غير مسجل');
  }

  void _showResult(String title, String message, {bool success = true}) {
    if (success) _confettiController.play();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SelectableText(message),
        actions: [
          if (success)
            TextButton.icon(
              icon: const Icon(Icons.copy),
              label: const Text('نسخ'),
              onPressed: () => FlutterClipboard.copy(message),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تمام'),
          ),
        ],
      ),
    );
  }

  Future<void> _testLocalNotification() async {
    const android = AndroidNotificationDetails(
      'test',
      'Test',
      importance: Importance.high,
    );
    const ios = DarwinNotificationDetails();
    await _notifications.show(
      0,
      'يا وحش!',
      'الإشعار شغال 100%',
      const NotificationDetails(android: android, iOS: ios),
    );
    _showResult('إشعار محلي', 'تم الإرسال بنجاح!', success: true);
    await _audioPlayer.play(AssetSource('sounds/success.mp3'));
  }

  Future<void> _testLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) {
        await AppSettings.openAppSettings();
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      final coords = '${position.latitude}, ${position.longitude}';
      _showResult('الموقع', coords, success: true);
    } catch (e) {
      _showResult('خطأ في الموقع', e.toString(), success: false);
    }
  }

  Future<void> _testGoogleLogin() async {
    try {
      final user = await _googleSignIn.signIn();
      if (user != null) {
        final auth = await user.authentication;
        final credential = GoogleAuthProvider.credential(
          accessToken: auth.accessToken,
          idToken: auth.idToken,
        );
        await _auth.signInWithCredential(credential);
        _showResult('جوجل', 'مرحباً ${user.displayName}', success: true);
      }
    } catch (e) {
      _showResult('جوجل', e.toString(), success: false);
    }
  }

  Future<void> _testFirebaseDB() async {
    try {
      await _firestore.collection('test_logs').add({
        'message': 'اختبار من Ultimate Test Screen',
        'time': FieldValue.serverTimestamp(),
        'user': _userId,
      });
      _showResult('Firebase DB', 'تم الحفظ بنجاح!', success: true);
    } catch (e) {
      _showResult('Firebase DB', e.toString(), success: false);
    }
  }

  Future<void> _testPushNotification() async {
    _showResult('FCM Token', _fcmToken, success: true);
  }

  Future<void> _testBusArrival() async {
    const android = AndroidNotificationDetails(
      'bus_arrival', // توحيد الـ ID مع الخدمة
      'الحافلة وصلت',
      channelDescription: 'إشعارات وصول الحافلة',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('bus_arrived'),
    );
    await _notifications.show(
      1,
      'الحافلة وصلت!',
      'خط 105 عند محطة رمسيس',
      const NotificationDetails(android: android),
    );
    await Vibration.vibrate(pattern: [500, 1000, 500]);
    await _audioPlayer.play(AssetSource('sounds/bus_arrived.mp3'));
    _showResult('الحافلة وصلت', 'تم إرسال إشعار تجريبي', success: true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset(
              'assets/images/play_store_512.png',
              width: 32,
              height: 32,
            ),
            const SizedBox(width: 8),
            const Text(
              'لوحة تحكم المطور',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shield_moon),
            onPressed: () => setState(() => _isDevMode = !_isDevMode),
            tooltip: 'وضع المطور',
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark
                    ? [Colors.grey[900]!, Colors.black]
                    : [Colors.blue[700]!, Colors.blue[400]!],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Status Card
                Card(
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Text(
                          'حالة النظام',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Divider(),
                        _statusRow(
                          'الإنترنت',
                          _connectionStatus,
                          _connectionStatus.contains('متصل'),
                        ),
                        _statusRow(
                          'FCM Token',
                          _fcmToken.length > 10 ? 'متوفر' : 'غير متوفر',
                          _fcmToken.length > 10,
                        ),
                        _statusRow(
                          'المستخدم',
                          _userId.length > 10 ? 'مسجل' : 'غير مسجل',
                          _userId.length > 10,
                        ),
                      ],
                    ),
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _testButton(
                        'إشعار محلي',
                        Icons.notifications,
                        _testLocalNotification,
                        'animations/notification.json',
                      ),
                      _testButton(
                        'تحديد الموقع',
                        Icons.location_on,
                        _testLocation,
                        'animations/location.json',
                      ),
                      _testButton(
                        'تسجيل جوجل',
                        Icons.g_mobiledata,
                        _testGoogleLogin,
                        'animations/google.json',
                      ),
                      _testButton(
                        'Firebase DB',
                        Icons.cloud,
                        _testFirebaseDB,
                        'animations/firebase.json',
                      ),
                      _testButton(
                        'FCM Token',
                        Icons.token,
                        _testPushNotification,
                        'animations/token.json',
                      ),
                      _testButton(
                        'الحافلة وصلت!',
                        Icons.directions_bus,
                        _testBusArrival,
                        'animations/bus_arrived.json',
                      ),
                      _testButton(
                        'مشاركة',
                        Icons.share,
                        () => SharePlus.instance.share(
                          ShareParams(text: 'تطبيق دليل حافلات إنجاز'),
                        ),
                        'animations/share.json',
                      ),
                      _testButton(
                        'نسخ',
                        Icons.copy,
                        () => FlutterClipboard.copy('تم النسخ!'),
                        'animations/copy.json',
                      ),
                      _testButton(
                        'صوت',
                        Icons.volume_up,
                        () => _audioPlayer.play(AssetSource('sounds/test.mp3')),
                        'animations/sound.json',
                      ),
                      _testButton(
                        'اهتزاز',
                        Icons.vibration,
                        () => Vibration.vibrate(),
                        'animations/vibration.json',
                      ),
                    ],
                  ),
                ),

                // Palestine
                GestureDetector(
                  onTap: () => _showResult(
                    'فلسطين حرة',
                    'من النهر إلى البحر...',
                    success: true,
                  ),
                  child: Image.asset('assets/palestine.png', height: 60),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(String label, String value, bool success) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            success ? Icons.check_circle : Icons.error,
            color: success ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: success ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _testButton(
    String title,
    IconData icon,
    VoidCallback onPressed,
    String lottieAsset,
  ) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Lottie.asset(lottieAsset, width: 50, height: 50),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onPressed,
      ),
    );
  }
}
