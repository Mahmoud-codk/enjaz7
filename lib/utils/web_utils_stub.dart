// ultimate_url_launcher.dart
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'app_logger.dart'; // EgyptianLogger
import 'dart:io' show Platform;
// import 'dart:html' as html; // لا تستخدمه مباشرة هنا إلا في ملف مخصص للويب فقط

class UltimateLinkLauncher {
  // فتح رابط عادي
  static Future<bool> open(String url, {String? name}) async {
    try {
      EgyptianLogger.i('فتح رابط: $url');

      // if (kIsWeb) {
      //   html.window.open(url, name ?? '_blank');
      //   return true;
      // }

      final uri = Uri.parse(url);
      final scheme = uri.scheme;

      // 1. واتساب
      if (scheme == 'whatsapp' || url.contains('wa.me')) {
        return await _openWhatsApp(url);
      }

      // 2. تليجرام
      if (scheme == 'tg' || url.contains('t.me')) {
        return await _openTelegram(url);
      }

      // 3. جوجل مابس
      if (url.contains('maps.google.com') || url.contains('goo.gl/maps')) {
        return await _openGoogleMaps(uri);
      }

      // 4. فيسبوك / إنستا / تيك توك
      if (url.contains('facebook.com') ||
          url.contains('instagram.com') ||
          url.contains('tiktok.com')) {
        return await _openInAppBrowser(url, title: 'فيسبوك');
      }

      // 5. فلسطين
      if (url.contains('palestine')) {
        await _openPalestineMap();
        return true;
      }

      // 6. Deep Link داخل التطبيق
      if (uri.scheme == 'busguide') {
        return await _handleDeepLink(uri);
      }

      // 7. فتح عادي مع In-App إذا ممكن
      return await _launchWithFallback(url);
    } catch (e, s) {
      EgyptianLogger.e('فشل فتح الرابط: $url', error: e, stackTrace: s);
      return false;
    }
  }

  // واتساب
  static Future<bool> _openWhatsApp(String url) async {
    final whatsappUrl = url.replaceFirst('whatsapp://', 'https://wa.me/');
    final message =
        url.contains('text=') ? Uri.decodeFull(url.split('text=')[1]) : '';

    _showSnack('جاري فتح واتساب...');

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      final appUrl = Uri.parse(whatsappUrl);
      if (await canLaunchUrl(appUrl)) {
        return await launchUrl(appUrl, mode: LaunchMode.externalApplication);
      }
    }

    return await launchUrl(Uri.parse(whatsappUrl),
        mode: LaunchMode.externalApplication);
  }

  // تليجرام
  static Future<bool> _openTelegram(String url) async {
    _showSnack('جاري فتح تليجرام...');
    final uri = Uri.parse(url);
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // جوجل مابس
  static Future<bool> _openGoogleMaps(Uri uri) async {
    final lat = uri.queryParameters['q'] ?? uri.queryParameters['ll'];
    if (lat != null) {
      final mapsUrl = (!kIsWeb && Platform.isIOS)
          ? 'https://maps.apple.com/?q=$lat'
          : 'https://www.google.com/maps/search/?api=1&query=$lat';

      return await launchUrl(Uri.parse(mapsUrl),
          mode: LaunchMode.externalApplication);
    }
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // In-App Browser
  static Future<bool> _openInAppBrowser(String url,
      {String title = 'تصفح'}) async {
    // Note: InAppWebViewController requires proper initialization in a Flutter widget context
    // For stub implementation, we'll just return true
    return true;
  }

  // فلسطين
  static Future<void> _openPalestineMap() async {
    _showSnack('من النهر إلى البحر... فلسطين حرة');
    final url = 'https://www.google.com/maps/@31.9474,35.2272,10z';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    EgyptianLogger.palestine();
  }

  // Deep Link
  static Future<bool> _handleDeepLink(Uri uri) async {
    final path = uri.path;
    if (path.startsWith('/line/')) {
      final line = path.split('/').last;
      // انتقل لصفحة الخط
      // Navigator.pushNamed(context, '/line', arguments: line);
      EgyptianLogger.i('Deep Link: خط $line');
      return true;
    }
    return false;
  }

  // فتح مع Fallback
  static Future<bool> _launchWithFallback(String url) async {
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      return await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
        webOnlyWindowName: kIsWeb ? '_blank' : null,
      );
    } else {
      _showSnack('مش قادر أفتح الرابط ده');
      return false;
    }
  }

  // مشاركة
  static Future<void> share(String text, {String? url}) async {
    await SharePlus.instance.share(ShareParams(text: '$text\n$url'));
  }

  // إشعار مؤقت
  static void _showSnack(String message) {
    // يمكن استخدام ScaffoldMessenger
    debugPrint(message);
  }

  // فتح خط واتساب دعم
  static Future<void> openSupport() async {
    await open('https://wa.me/201234567890?text=مرحبًا، عايز أسأل عن خط 105');
  }

  // فتح صفحة فلسطين
  static Future<void> openPalestineSupport() async {
    await open('https://www.palestinecampaign.org');
  }
}
