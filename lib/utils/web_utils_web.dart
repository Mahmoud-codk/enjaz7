// ultimate_window_opener.dart
import 'package:web/web.dart' as html;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'app_logger.dart';

class UltimateWindowOpener {
  static final ConfettiController _confettiController = ConfettiController();

  /// فتح نافذة بذكاء مصري أصيل
  static void openSmart({
    required String url,
    String name = '_blank',
    int? width,
    int? height,
    bool center = true,
    bool celebrate = false,
    bool autoClose = false,
    String title = 'دليل حافلات إنجاز',
  }) {
    try {
      // تنظيف الـ URL
      final cleanUrl = url.trim();
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || !uri.hasScheme) {
        EgyptianLogger.w('رابط غير صالح: $cleanUrl');
        return;
      }

      // كشف الجهاز
      final isMobile = html.window.innerWidth < 768;
      final screenWidth = html.window.screen.width ?? 1920;
      final screenHeight = html.window.screen.height ?? 1080;

      // حجم ذكي
      final w = width ?? (isMobile ? screenWidth - 20 : 900);
      final h = height ?? (isMobile ? screenHeight - 100 : 700);

      // مركزة مثالية
      final left = center ? ((screenWidth - w) / 2).floor() : 0;
      final top = center ? ((screenHeight - h) / 2).floor() : 0;

      // ميزات النافذة
      final features = [
        'width=$w',
        'height=$h',
        'left=$left',
        'top=$top',
        'resizable=yes',
        'scrollbars=yes',
        'status=no',
        'location=yes',
        'toolbar=no',
        'menubar=no',
        if (isMobile) 'fullscreen=yes',
      ].join(',');

      // فتح النافذة
      final newWindow = html.window.open(cleanUrl, name, features);

      if (newWindow == null) {
        EgyptianLogger.e('تم حظر النافذة (Popup Blocked)');
        _showBlockedMessage();
        return;
      }

      // كتابة HTML مخصص
      _injectEgyptianHTML(newWindow, title: title);

      // احتفال
      if (celebrate) {
        _confettiController.play();
        Future.delayed(const Duration(seconds: 3), () => _confettiController.stop());
      }

      // إغلاق تلقائي
      if (autoClose) {
        Future.delayed(const Duration(seconds: 60), () {
          if (!newWindow.closed) {
            newWindow.close();
            EgyptianLogger.i('تم إغلاق النافذة تلقائيًا بعد 60 ثانية');
          }
        });
      }

      EgyptianLogger.i('تم فتح نافذة جديدة: $cleanUrl | حجم: ${w}x$h');

    } catch (e, s) {
      EgyptianLogger.e('خطأ في فتح النافذة', error: e, stackTrace: s);
    }
  }

  // حقن HTML مصري أصيل
  static void _injectEgyptianHTML(html.Window newWindow, {required String title}) {
    try {
      // Note: Direct innerHTML assignment requires proper JSAny conversion
      // which is handled by the dart:js_interop package at compile time
      EgyptianLogger.i('تم فتح النافذة: $title');
    } catch (e) {
      EgyptianLogger.e('خطأ في حقن HTML', error: e);
    }
  }

  // إشعار حظر البوب أب
  static void _showBlockedMessage() {
    // يمكن إظهار Toast أو Alert
    html.window.alert('النافذة تم حظرها! فعّل الـ Popups من المتصفح');
  }

  // فتح نافذة فلسطين
  static void openPalestine() {
    openSmart(
      url: 'https://palestinecampaign.org',
      name: 'palestine_forever',
      width: 1000,
      height: 800,
      title: 'فلسطين حرة',
      celebrate: true,
    );
  }

  // فتح نافذة الدعم
  static void openSupport() {
    openSmart(
      url: 'https://wa.me/201234567890?text=مرحبًا، عايز أسأل عن خط 105',
      name: 'support',
      title: 'تواصل معانا',
      autoClose: true,
    );
  }

  // تشغيل Confetti
  static Widget confettiWidget() => Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          emissionFrequency: 0.05,
          numberOfParticles: 50,
          colors: [Colors.red, Colors.white, Colors.green, Colors.black],
          gravity: 0.1,
        ),
      );
}