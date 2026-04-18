import 'package:url_launcher/url_launcher.dart' as url_launcher;
import 'package:share_plus/share_plus.dart';

/// Ultimate URL Launcher - consolidated URL opening utility
class UltimateLinkLauncher {
  /// Open a URL in the default browser or app (alias for launchUrl)
  static Future<bool> open(String url) => launchUrl(url);

  /// Share a URL using system share sheet
  static Future<bool> share(
    String text, {
    String? url,
  }) async {
    try {
      final shareText = url != null ? '$text $url' : text;
      await Share.share(shareText);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Launch a URL in the default browser or app
  static Future<bool> launchUrl(String url) async {
    try {
      if (url.isEmpty) return false;

      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      // Try to launch with mode that opens in default app/browser
      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launch a phone call
  static Future<bool> launchPhone(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanNumber.isEmpty) return false;

      final uri = Uri(scheme: 'tel', path: cleanNumber);
      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launch WhatsApp (with optional message)
  static Future<bool> launchWhatsApp(
    String phoneNumber, {
    String? message,
  }) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
      if (cleanNumber.isEmpty) return false;

      String url = 'https://wa.me/$cleanNumber';
      if (message != null && message.isNotEmpty) {
        url += '?text=${Uri.encodeComponent(message)}';
      }

      final uri = Uri.tryParse(url);
      if (uri == null) return false;

      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launch an email
  static Future<bool> launchEmail(
    String email, {
    String? subject,
    String? body,
  }) async {
    try {
      if (email.isEmpty) return false;

      final uri = Uri(
        scheme: 'mailto',
        path: email,
        queryParameters: {
          if (subject != null && subject.isNotEmpty) 'subject': subject,
          if (body != null && body.isNotEmpty) 'body': body,
        },
      );

      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(uri);
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launch Google Maps with coordinates
  static Future<bool> launchMaps(double latitude, double longitude) async {
    try {
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
        return false;
      }

      final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
      );

      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Launch Google Maps directions
  static Future<bool> launchDirections({
    required double destLat,
    required double destLng,
    String? destName,
  }) async {
    try {
      final label = destName ?? '$destLat,$destLng';
      final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$destLat,$destLng&destination_place_id=$label',
      );

      if (await url_launcher.canLaunchUrl(uri)) {
        return await url_launcher.launchUrl(
          uri,
          mode: url_launcher.LaunchMode.externalApplication,
        );
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
