import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

/// خدمة التكامل مع Gemini AI
/// ملاحظة: يجب أن يكون مفتاح API مرتبكاً بحساب الخدمة (Service Account)
/// كما هو محدد في إعدادات Google Cloud للمشروع enjaz7-a49f2
class GeminiService {
  static Future<String> _getApiKey() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.fetchAndActivate().timeout(const Duration(seconds: 3));
      final String key = remoteConfig.getString('gemini_api_key');
      if (key.isNotEmpty) return key;
    } catch (e) {
      debugPrint('⚠️ فشل جلب مفتاح Gemini: $e');
    }
    // العودة للمفتاح الافتراضي في حال فشل Remote Config أو كان فارغاً
    return 'AIzaSyAApGehTUv-AjNJO5ByNgBSKdHP25cVdPU';
  }

  /// توليد رد ذكي للمسافرين (مثلاً: اقتراح أفضل وقت للتحرك)
  static Future<String?> getAIAdvice(String userPrompt) async {
    final apiKey = await _getApiKey();
    if (apiKey.isEmpty) {
      debugPrint('❌ Gemini API Key is missing');
      return 'الخدمة الذكية غير متاحة حالياً.';
    }

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey';

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              "contents": [
                {
                  "parts": [
                    {
                      "text":
                          "أنت مساعد خبير في حافلات القاهرة لتطبيق إنجاز. $userPrompt"
                    }
                  ]
                }
              ]
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        }
      } else {
        debugPrint(
            'Gemini API Error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('⚠️ خطأ في الاتصال بـ Gemini: $e');
    }
    return null;
  }
}
