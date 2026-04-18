import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:developer' as developer;
import 'package:lottie/lottie.dart';
import 'package:confetti/confetti.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import 'home_screen.dart';
import '../utils/responsive.dart';

class UltimateSplashScreen extends StatefulWidget {
  final bool isLoggedIn;

  const UltimateSplashScreen({super.key, required this.isLoggedIn});

  @override
  State<UltimateSplashScreen> createState() => _UltimateSplashScreenState();
}

class _UltimateSplashScreenState extends State<UltimateSplashScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _lottieController;
  bool _isLoggedIn = false;
  String _statusText = 'جاري تحميل البيانات...';
  String _lastUpdate = 'منذ قليل';
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    developer.log("ULTIMATE SPLASH STARTED - ${DateTime.now()}");

    _isLoggedIn = widget.isLoggedIn;

    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _lottieController = AnimationController(vsync: this, duration: const Duration(seconds: 3));

    // إخفاء شريط الحالة لتجربة Splash فاخرة
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Move heavy operations to post-frame callback to prevent UI blocking
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkConnectivity();
      await _loadLastUpdate();
      _startEpicAnimation();

      // Fallback في حالة التعليق
      Future.delayed(const Duration(seconds: 10), () {
        if (mounted) {
          developer.log('Splash fallback timeout reached, navigating to next screen');
          _navigateToNextScreen();
        }
      });
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _lottieController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _hasInternet = connectivityResult != ConnectivityResult.none;
      _statusText = _hasInternet ? 'جاري تحميل البيانات...' : 'وضع عدم الاتصال';
    });
  }

  Future<void> _loadLastUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastUpdate = prefs.getString('last_update') ?? 'منذ قليل';
    });
  }

  void _startEpicAnimation() async {
    _lottieController.forward();

    await Future.delayed(const Duration(seconds: 2));

    try {
      _confettiController.play();
    } catch (e) {
      developer.log('Confetti failed: $e');
    }

    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      _navigateToNextScreen();
    }
  }

  void _navigateToNextScreen() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  Widget _fallbackLogo() {
    return Container(
      width: Responsive.w(context, 200),
      height: Responsive.w(context, 200),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.directions_bus, size: 80, color: Colors.white),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // خلفية متدرجة فاخرة
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.grey[900]!, Colors.black]
                    : [const Color(0xFF1E3A8A), const Color(0xFF3B82F6), const Color(0xFF60A5FA)],
              ),
            ),
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 80,
              gravity: 0.15,
              colors: const [Colors.red, Colors.green, Colors.black, Colors.white],
            ),
          ),

          // المحتوى الرئيسي
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  // Lottie Animation مع فحص وجود الملف
                  Hero(
                    tag: 'splash_logo',
                    child: Lottie.asset(
                      'assets/animations/bus_loading.json',
                      controller: _lottieController,
                      onLoaded: (composition) {
                        _lottieController
                          ..duration = composition.duration
                          ..forward(from: 0);
                      },
                      errorBuilder: (context, error, stackTrace) {
                        developer.log('Lottie error: $error');
                        return _fallbackLogo();
                      },
                      width: Responsive.w(context, 280),
                      height: Responsive.w(context, 280),
                      fit: BoxFit.contain,
                    ),
                  ),

                  SizedBox(height: Responsive.h(context, 32)),

                  Text(
                    'دليل حافلات إنجاز',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.sp(context, 28),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                      shadows: const [Shadow(color: Colors.black45, blurRadius: 10)],
                    ),
                  ),

                  SizedBox(height: Responsive.h(context, 12)),

                  Text(
                    'أقوى تطبيق مواصلات في مصر',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: Responsive.sp(context, 18),
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  SizedBox(height: Responsive.h(context, 40)),

                  Text(
                    _statusText,
                    style: TextStyle(color: Colors.white70, fontSize: Responsive.sp(context, 14)),
                  ),

                  SizedBox(height: Responsive.h(context, 8)),

                  Text(
                    'آخر تحديث: $_lastUpdate',
                    style: TextStyle(color: Colors.white60, fontSize: Responsive.sp(context, 12)),
                  ),

                  SizedBox(height: Responsive.h(context, 40)),

                  CircularProgressIndicator(
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: Responsive.w(context, 5),
                  ),

                  SizedBox(height: Responsive.h(context, 60)),

                  // رسالة فلسطين
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(context, 32),
                      vertical: Responsive.h(context, 16),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white30),
                    ),
                    child: const Text(
                      'من النهر إلى البحر... فلسطين حرة',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  SizedBox(height: Responsive.h(context, 20)),

                  // علم فلسطين
                  Image.asset(
                    'assets/palestine.png',
                    width: Responsive.w(context, 80),
                    height: Responsive.h(context, 50),
                    errorBuilder: (context, error, stackTrace) => const SizedBox(),
                  ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}