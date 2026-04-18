import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class StationTranslationService {
  static final StationTranslationService _instance = StationTranslationService._internal();
  factory StationTranslationService() => _instance;
  StationTranslationService._internal();

  Map<String, String> _dictionary = {};
  bool _isInit = false;

  /// جلب القاموس الحالي (للبحث)
  Map<String, String> getDictionary() => Map.unmodifiable(_dictionary);

  /// تهيئة القاموس من ملف JSON
  Future<void> initialize() async {
    if (_isInit) return;
    try {
      final String response = await rootBundle.loadString('assets/data/stops_en.json');
      final data = await json.decode(response);
      if (data is Map<String, dynamic>) {
        _dictionary = data.map((key, value) => MapEntry(key, value.toString()));
      }
      _isInit = true;
      debugPrint('StationTranslationService: Dictionary loaded with ${_dictionary.length} entries');
    } catch (e) {
      debugPrint('StationTranslationService: Error loading dictionary: $e');
      // Fallback to empty dictionary, logic will use transliteration
      _isInit = true; 
    }
  }

  /// ترجمة اسم المحطة أو تحويله لفظياً
  String translate(String arabicName) {
    if (arabicName.isEmpty) return '';
    
    // 1. البحث في القاموس أولاً
    if (_dictionary.containsKey(arabicName.trim())) {
      return _dictionary[arabicName.trim()]!;
    }

    // 2. إذا لم يوجد، استخدام التحويل اللفظي التلقائي
    return _autoTransliterate(arabicName);
  }

  /// خوارزمية التحويل اللفظي التلقائي (Arabic to English Transliteration)
  String _autoTransliterate(String input) {
    String text = input.trim();
    
    // التعامل مع "ال" التعريف
    if (text.startsWith('ال')) {
      text = 'Al-' + text.substring(2);
    }

    // خريطة الحروف
    final map = {
      'أ': 'A', 'ا': 'A', 'إ': 'I', 'آ': 'A',
      'ب': 'B', 'ت': 'T', 'ث': 'th', 'ج': 'J',
      'ح': 'H', 'خ': 'kh', 'د': 'D', 'ذ': 'th',
      'ر': 'R', 'ز': 'Z', 'س': 'S', 'ش': 'sh',
      'ص': 'S', 'ض': 'D', 'ط': 'T', 'ظ': 'th',
      'ع': 'A', 'غ': 'gh', 'ف': 'F', 'ق': 'Q',
      'ك': 'K', 'ل': 'L', 'م': 'M', 'ن': 'N',
      'ه': 'H', 'و': 'W', 'ي': 'Y', 'ى': 'a',
      'ة': 'a', 'ؤ': 'u', 'ئ': 'e', 'ء': 'a',
      'لا': 'La',
    };

    String result = '';
    for (int i = 0; i < text.length; i++) {
      String char = text[i];
      // Check for double characters (like لا)
      if (i < text.length - 1 && char == 'ل' && text[i+1] == 'ا') {
        result += 'La';
        i++;
        continue;
      }
      result += map[char] ?? char;
    }

    // تنظيف النتيجة (Camel Case)
    if (result.isNotEmpty) {
      result = result[0].toUpperCase() + result.substring(1);
    }
    
    return result;
  }
}
