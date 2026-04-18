// app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/services.dart';

class UltimateAppTheme {
  // ألوان مصرية أصيلة
  static const Color nileBlue = Color(0xFF0D47A1);        // أزرق النيل
  static const Color deltaGreen = Color(0xFF2E7D32);      // أخضر الدلتا
  static const Color egyptRed = Color(0xFFD32F2F);        // أحمر العلم
  static const Color pyramidGold = Color(0xFFFFB300);     // ذهب الأهرام
  static const Color cairoSand = Color(0xFFF5F5DC);       // رمل إنجاز

  // ألوان فلسطين
  static const Color palestineBlack = Color(0xFF000000);
  static const Color palestineWhite = Color(0xFFFFFFFF);
  static const Color palestineGreen = Color(0xFF007A3D);
  static const Color palestineRed = Color(0xFFCE1126);

  // Gradient للـ AppBar
  static final LinearGradient nileGradient = LinearGradient(
    colors: [nileBlue, nileBlue.withValues(alpha: 0.8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Theme - مصر الصبح
  static ThemeData lightTheme(BuildContext context) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        fontFamily: GoogleFonts.tajawal().fontFamily,
        primaryColor: nileBlue,
        scaffoldBackgroundColor: cairoSand,
        colorScheme: ColorScheme.light(
          primary: nileBlue,
          secondary: pyramidGold,
          tertiary: deltaGreen,
          error: egyptRed,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: const Color(0xFF1A1A1A),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
          actionsIconTheme: const IconThemeData(color: Colors.white),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarBrightness: Brightness.dark,
          ),
        ),
        textTheme: GoogleFonts.tajawalTextTheme().copyWith(
          displayLarge: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: nileBlue),
          headlineLarge: GoogleFonts.cairo(fontSize: 24, fontWeight: FontWeight.bold, color: nileBlue),
          titleLarge: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nileBlue),
          bodyLarge: const TextStyle(fontSize: 16, color: Color(0xFF212121)),
          labelLarge: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: nileBlue,
            elevation: 8,
            shadowColor: nileBlue.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
          ).copyWith(
            overlayColor: WidgetStateProperty.all(pyramidGold.withValues(alpha: 0.3)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: nileBlue,
            side: BorderSide(color: nileBlue, width: 2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: nileBlue.withValues(alpha: 0.3)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: nileBlue, width: 2),
          ),
          labelStyle: GoogleFonts.tajawal(color: nileBlue),
          hintStyle: GoogleFonts.tajawal(color: Colors.grey),
          prefixIconColor: nileBlue,
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: pyramidGold,
          foregroundColor: Colors.white,
          elevation: 10,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: nileBlue,
          unselectedItemColor: Colors.grey,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      );

  // Dark Theme - مصر الليل
  static ThemeData darkTheme(BuildContext context) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: GoogleFonts.tajawal().fontFamily,
        primaryColor: nileBlue,
        scaffoldBackgroundColor: const Color(0xFF0A0E17),
        colorScheme: ColorScheme.dark(
          primary: nileBlue,
          secondary: pyramidGold,
          tertiary: deltaGreen,
          error: egyptRed,
          surface: const Color(0xFF1E1E1E),
        ),
        appBarTheme: AppBarTheme(
          elevation: 0,
          centerTitle: true,
          backgroundColor: Colors.transparent,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 1.5,
          ),
          actionsIconTheme: const IconThemeData(color: pyramidGold),
        ),
        textTheme: GoogleFonts.tajawalTextTheme(ThemeData.dark().textTheme).copyWith(
          displayLarge: GoogleFonts.cairo(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
          bodyLarge: const TextStyle(color: Colors.white70),
          labelLarge: const TextStyle(color: Colors.white),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: pyramidGold,
            foregroundColor: palestineBlack,
            elevation: 10,
            shadowColor: pyramidGold.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );

  // وضع فلسطين (خاص)
  static ThemeData palestineTheme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: palestineBlack,
        primaryColor: palestineRed,
        colorScheme: const ColorScheme.dark(
          primary: palestineRed,
          secondary: palestineGreen,
          surface: palestineBlack,
          onPrimary: palestineWhite,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: palestineBlack,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: palestineWhite,
          ),
          actionsIconTheme: const IconThemeData(color: palestineGreen),
        ),
        textTheme: GoogleFonts.tajawalTextTheme().apply(
          bodyColor: palestineWhite,
          displayColor: palestineWhite,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: palestineGreen,
            foregroundColor: palestineWhite,
            textStyle: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      );

  // تشغيل Confetti عند أول فتح
  static void celebrateFirstLaunch(ConfettiController controller) {
    controller.play();
    Future.delayed(const Duration(seconds: 5), () {
      controller.stop();
    });
  }

  // رسالة ترحيب
  static String welcomeMessage() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير يا وحش!';
    if (hour < 18) return 'مساء الخير يا بطل!';
    return 'من النهر إلى البحر... فلسطين حرة';
  }
}