import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'firebase_options.dart'; // الملف الذي تم توليده
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import 'common/globs.dart';
import 'common/location_manager.dart';
import 'common/my_http_overrides.dart';
import 'services/service_call.dart';
import 'services/socket_manager.dart';
import 'models/bus_line.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/history_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/test_features_screen.dart' as test;
import 'screens/map_screen.dart' as map;
import 'screens/map_with_search_screen.dart' as map_search;
import 'screens/bus_line_details_screen.dart';
import 'package:enjaz7/screens/whatsapp_chat_screen.dart';
import 'utils/theme.dart' as theme;
import 'providers/favorites_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/map_provider.dart';
import 'providers/history_provider.dart';
import 'services/firebase_messaging_service.dart' as fcm;
import 'services/station_translation_service.dart';
import 'services/deep_link_service.dart';
import 'services/ad_service.dart';
import 'services/notification_service.dart';
import 'services/centralized_location_service.dart';
import 'services/location_notification_service.dart';
import 'services/app_state_service.dart';
import 'providers/map_state.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized in main() - no need to initialize again
  debugPrint('Handling a background message: ${message.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    HttpOverrides.global = MyHttpOverrides();
  }

  // Initialize Hive
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(BusLineAdapter());

  // Initialize Firebase only once (if not already initialized)
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  // تسجيل معالج الرسائل في الخلفية
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Initialize AdMob
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
  }

  // Initialize Station Translation Service
  await StationTranslationService().initialize();

  // Initialize Remote Config defaults
  try {
    final remoteConfig = FirebaseRemoteConfig.instance;
    await remoteConfig.setDefaults({
      'google_maps_api_key': 'AIzaSyAApGehTUv-AjNJO5ByNgBSKdHP25cVdPU',
    });
    // Start background fetch
    remoteConfig.fetchAndActivate().catchError((e) {
      debugPrint('Remote Config Fetch Error: $e');
      return false;
    });
  } catch (e) {
    debugPrint('Remote Config Initialization Error: $e');
  }

  prefs = await SharedPreferences.getInstance();

  ServiceCall.userUUID = Globs.udValueString("uuid");

  if (ServiceCall.userUUID == "") {
    ServiceCall.userUUID = const Uuid().v6();
    Globs.udStringSet(ServiceCall.userUUID, "uuid");
  }

  if (!kIsWeb) {
    SocketManager.shared.init(SVKey.mainUrl);
    LocationManager.shared.initLocation();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MapState()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String _currentRoute = '/';
  ThemeMode _themeMode = ThemeMode.light; // إضافة متغير وضع السمة
  bool _hasSeenOnboarding = false;
  bool _fcmAvailable = false; // used to prevent FCM errors from crashing app
  Locale _locale = const Locale('ar', 'EG'); // الافتراضي عربي

  // 🔥 Performance optimizations
  Timer? _lazyTimer;
  // ignore: unused_field
  bool _heavyLogicLoaded = false;

  // === AdMob Variables ===
  late BannerAd _bannerAd;
  bool _isBannerAdReady = false;
  bool _isDeepLinkInitialized = false; // لمنع التكرار

  // Widget to display banner ad at bottom of screen
  Widget _buildBannerAd() {
    if (_isBannerAdReady) {
      return Container(
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd),
        width: _bannerAd.size.width.toDouble(),
        height: _bannerAd.size.height.toDouble(),
      );
    }
    return const SizedBox.shrink();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 🔥 الحل #1: فصل التحميل عن الـ logic الثقيل
    _loadApp();

    Future.microtask(() {
      _heavyInitLogic(); // في microtask
      _initializeApp(); // إضافة استدعاء التهيئة الأساسية
    });

    // 🔥 الحل #7: تحميل تدريجي
    _stagedLoading();

    if (!kIsWeb) {
      _initializeAds();
    }

    // Initialize history
    Future.microtask(() {
      if (mounted) {
        context.read<HistoryProvider>().loadHistory();
      }
    });
  }

  void _initializeAds() {
    // === Banner Ad ===
    _bannerAd = BannerAd(
      adUnitId: 'ca-app-pub-5517764020832780/1803243933',
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          setState(() {
            _isBannerAdReady = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('Banner Ad Failed: $error');
        },
      ),
    );
    _bannerAd.load();

    // Initialize and show startup ads from centralized AdService
    AdService.loadInitialAds().then((_) {
      // Small delay to allow splash screen to be visible before showing App Open ad
      Future.delayed(const Duration(milliseconds: 1200), () {
        AdService.showStartupAds();
      });
    });
  }

  // 🔥 الحل #1: تحميل التطبيق فقط
  void _loadApp() {
    if (kDebugMode) {
      print('تحميل التطبيق...');
    }
  }

  // 🔥 الحل #1: الـ logic الثقيل منفصل
  void _heavyInitLogic() {
    // محاكاة Firebase + Ads
    if (kDebugMode) {
      print('بدء الـ heavy logic (Firebase + Ads)...');
    }
    // يمكن إضافة منطق ثقيل هنا إذا لزم
  }

  // 🔥 الحل #7: تحميل تدريجي
  void _stagedLoading() {
    // المرحلة 1: الإعداد الأساسي بعد 300ms
    _lazyTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (kDebugMode) print('تم تحميل الإعداد الأساسي lazy');
      }
    });

    // المرحلة 2: محاكاة Ads + Firebase بعد ثانيتين
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        _heavyLogicLoaded = true;
        if (kDebugMode) {
          print('✅ تم تحميل Ads + Firebase');
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    await _loadLoginStatus();
    await _loadCurrentRoute();
    await _loadThemeMode(); // تحميل وضع السمة
    await _loadOnboardingStatus();
    await _loadLanguage(); // تحميل اللغة
    await _initializeFCM();
    await _initializeGPS();

    // ✅ Restore persistent trip state (حفظ البيانات حتى بعد الإغلاق)
    try {
      final data = await AppStateService.loadTrip();
      if (data['notificationEnabled'] == true &&
          (data['targetStation'] ?? '').isNotEmpty) {
        debugPrint(
            '🔄 استعادة الرحلة: ${data['start']} → ${data['targetStation']}, الإشعارات مفعلة');
        // الخدمة الخلفية تعيد التشغيل تلقائياً من prefs (monitoring_stops)
        // فحص دفاعي: إذا كانت المراقبة مفعلة ولكن الخدمة لا تعمل، أعد تشغيلها.
        final locationService = UltimateLocationNotificationService(
            stops: []); // إنشاء نسخة مؤقتة للتحقق
        if (data['notificationEnabled'] == true &&
            !await FlutterForegroundTask.isRunningService) {
          debugPrint(
              'خدمة الخلفية كان من المفترض أن تعمل، جاري إعادة التشغيل...');
          // إعادة التهيئة باستخدام المحطات والوجهة الأخيرة المعروفة
          await locationService.startMonitoring(
              destination: data['targetStation'], lineId: data['lineId']);
        }
      }
    } catch (e) {
      debugPrint('خطأ في استعادة حالة الرحلة: $e');
    }
  }

  Future<void> _initializeFCM() async {
    try {
      // Initialize FCM without confetti controller for now
      await fcm.FirebaseMessagingService.initialize(confettiController: null);
      debugPrint('Firebase Messaging initialized successfully');

      // Initialize NotificationService for badge
      await NotificationService().initialize();

      final localPrefs = await SharedPreferences.getInstance();

      // للحصول على التوكن
      String? token = await FirebaseMessaging.instance.getToken();
      debugPrint('🔔 FCM Token: $token');

      final apiHost = localPrefs.getString('api_url') ?? 'Not Configured';
      debugPrint('🚍 Live Tracking Host: $apiHost');

      // مستمع لتحديث التوكن إذا تغير أثناء تشغيل التطبيق
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (localPrefs.getString('last_fcm_token') == newToken) return;

        FirebaseFirestore.instance
            .collection('users_devices')
            .doc(ServiceCall.userUUID)
            .set({
          'fcm_token': newToken,
          'last_seen': FieldValue.serverTimestamp()
        }, SetOptions(merge: true));
        localPrefs.setString('last_fcm_token', newToken);
        debugPrint('🔄 FCM Token Refreshed and Saved');
      });

      // تحديث التوكن في قاعدة البيانات لضمان وصول الإشعارات
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users_devices')
            .doc(ServiceCall.userUUID)
            .set(
                {'fcm_token': token, 'last_seen': FieldValue.serverTimestamp()},
                SetOptions(merge: true));
        debugPrint('✅ FCM Token saved to Firestore for Live Tracking alerts');
      }

      // التحقق من إعدادات الإشعارات الدفعية
      final pushEnabled =
          localPrefs.getBool('push_notifications_enabled') ?? true;
      if (pushEnabled) {
        await fcm.FirebaseMessagingService.enablePushNotifications();
      }
    } catch (e) {
      debugPrint('Error initializing Firebase Messaging: $e');
      setState(() {
        _fcmAvailable = false;
      });
    }
  }

  Future<void> _initializeGPS() async {
    try {
      await CentralizedLocationService().startMonitoring();
      debugPrint('✅ GPS monitoring started successfully');
    } catch (e) {
      debugPrint('❌ GPS initialization failed: $e');
    }
  }

  @override
  void dispose() {
    // Dispose Banner Ad
    _bannerAd.dispose();

    // 🔥 تنظيف الذاكرة
    _lazyTimer?.cancel();

    // Save favorites before disposing
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final favoritesProvider =
            Provider.of<FavoritesProvider>(context, listen: false);
        // Force synchronous save
        favoritesProvider.ensureDataSaved().then((_) {
          debugPrint('✅ تم حفظ المفضلات عند الإغلاق (dispose)');
        }).catchError((e) {
          debugPrint('❌ خطأ في حفظ المفضلات عند الإغلاق: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المفضلات في dispose: $e');
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading login status: $e');
      }
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String route = prefs.getString('current_route') ?? '/';
      setState(() {
        _currentRoute = route;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading current route: $e');
      }
    }
  }

  Future<void> _loadThemeMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isDarkMode = prefs.getBool('dark_mode') ?? false;
      setState(() {
        _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading theme mode: $e');
      }
    }
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String lang = prefs.getString('language') ?? 'العربية';
      setState(() {
        _locale = lang == 'English'
            ? const Locale('en', 'US')
            : const Locale('ar', 'EG');
      });
    } catch (e) {
      debugPrint('Error loading language: $e');
    }
  }

  void updateLanguage(String lang) {
    setState(() {
      _locale = lang == 'English'
          ? const Locale('en', 'US')
          : const Locale('ar', 'EG');
    });
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bool hasSeen = prefs.getBool('hasSeenOnboarding') ?? false;
      setState(() {
        _hasSeenOnboarding = hasSeen;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading onboarding status: $e');
      }
    }
  }

  void updateThemeMode(bool isDarkMode) {
    setState(() {
      _themeMode = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    });
  }

  Future<void> _saveCurrentRoute(String route) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('current_route', route);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error saving current route: $e');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App is backgrounded, save current route and favorites
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final currentRoute =
              ModalRoute.of(navigatorKey.currentContext!)?.settings.name ?? '/';
          if (currentRoute != '/line_details') {
            _saveCurrentRoute(currentRoute);
          }
          _saveFavoritesOnPause();
        });
        break;
      case AppLifecycleState.detached:
        // App is being closed, ensure favorites are saved immediately
        _saveFavoritesOnDetach();
        break;
      case AppLifecycleState.resumed:
        // App is resumed, reload login status
        _loadLoginStatus();
        break;
      default:
        break;
    }
  }

  void _saveFavoritesOnPause() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final favoritesProvider =
            Provider.of<FavoritesProvider>(context, listen: false);
        // حفظ مباشر
        debugPrint('💾 جاري حفظ المفضلات عند إيقاف التطبيق...');
        favoritesProvider.ensureDataSaved().then((_) {
          debugPrint('✅ اكتمل حفظ المفضلات عند إيقاف التطبيق');
        }).catchError((e) {
          debugPrint('❌ خطأ في حفظ المفضلات عند الإيقاف: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المفضلات عند الإيقاف: $e');
    }
  }

  void _saveFavoritesOnDetach() {
    try {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        final favoritesProvider =
            Provider.of<FavoritesProvider>(context, listen: false);
        // حفظ مباشر عند الإغلاق
        debugPrint('💾 جاري حفظ المفضلات عند إغلاق التطبيق...');
        favoritesProvider.ensureDataSaved().then((_) {
          debugPrint('✅ اكتمل حفظ المفضلات عند إغلاق التطبيق');
        }).catchError((e) {
          debugPrint('❌ خطأ في حفظ المفضلات عند الإغلاق: $e');
        });
      }
    } catch (e) {
      debugPrint('❌ خطأ في حفظ المفضلات عند الإغلاق النهائي: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    return Builder(
      builder: (context) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isDeepLinkInitialized) {
            final authProvider =
                Provider.of<AuthProvider>(context, listen: false);
            authProvider.checkLoginStatus();
            // جلب روابط العمق مرة واحدة فقط لتجنب خطأ الـ Stream
            deepLinkService.init(context);
            _isDeepLinkInitialized = true;
          }
        });
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'دليل الحافلات',
          debugShowCheckedModeBanner: false,
          theme: theme.UltimateAppTheme.lightTheme(context),
          darkTheme: theme.UltimateAppTheme.darkTheme(context),
          themeMode: _themeMode, // إضافة وضع السمة الديناميكي
          builder: (context, child) {
            return Scaffold(
              body: child,
              bottomNavigationBar: _buildBannerAd(),
            );
          },
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ar', 'EG'), Locale('en', 'US')],
          locale: _locale,
          initialRoute: '/onboarding',
          onGenerateRoute: (settings) {
            Widget page;
            switch (settings.name) {
              case '/':
                page = _hasSeenOnboarding
                    ? UltimateSplashScreen(isLoggedIn: _isLoggedIn)
                    : const OnboardingScreen();
                break;
              case '/splash':
                page = UltimateSplashScreen(isLoggedIn: _isLoggedIn);
                break;
              case '/onboarding':
                page = const OnboardingScreen();
                break;
              case '/favorites':
                page = const FavoritesScreen();
                break;
              case '/history':
                page = const HistoryScreen();
                break;
              case '/settings':
                page = UltimateSettingsScreen(
                  onThemeChanged: updateThemeMode,
                  onLanguageChanged: updateLanguage,
                );
                break;
              case '/whatsapp_chat':
                page = const WhatsAppChatScreen();
                break;
              case '/test':
                page = const test.UltimateTestScreen();
                break;
              case '/map':
                page = const map.LiveMapScreen();
                break;
              case '/map-search':
                page = const map_search.UltimateMapScreen();
                break;
              case '/line_details':
                page = BusLineDetailsScreen(
                  busLine: settings.arguments as BusLine,
                );
                break;
              default:
                page = const UltimateSplashScreen(isLoggedIn: false);
            }

            // Wrap each page
            return MaterialPageRoute(
              builder: (context) => page,
              settings: settings,
            );
          },
          onUnknownRoute: (settings) {
            return MaterialPageRoute(
              builder: (context) =>
                  const UltimateSplashScreen(isLoggedIn: false),
            );
          },
        );
      },
    );
  }
}
