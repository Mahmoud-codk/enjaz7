import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:collection/collection.dart';
import 'app_logger.dart'; // EgyptianLogger

class UltimateStopsNormalizer {
  // فواصل مدعومة (مصرية أصيلة)
  static final RegExp _separators = RegExp(r'\s*[·•,،؛;|/\\\-–—]\s*');

  // كلمات زايدة شائعة
  static const Set<String> _junkWords = {
    'محطة', 'ميدان', 'كوبري', 'شارع', 'طريق', 'مدخل', 'مخرج',
    'قدام', 'جنب', 'تحت', 'فوق', 'عند', 'بجوار', 'أمام',
    'الرئيسي', 'الفرعي', 'الجديد', 'القديم',
  };

  // قاموس تصحيح إملائي مصري
  static const Map<String, String> _spellCorrections = {
    'التحرر': 'التحرير',
    'رمسيس': 'محطة رمسيس',
    'العتبة': 'ميدان العتبة',
    'الدقى': 'الدقي',
    'مدينة نصر': 'مدينة نصر',
    'المعادى': 'المعادي',
    'حدائق القبة': 'حدائق القبة',
    'كوبرى قصر النيل': 'كوبري قصر النيل',
    'الأهرام': 'الأهرام',
    'الجيزة': 'ميدان الجيزة',
    'المظلات': 'المظلات',
    'المنيب': 'المنيب',
    'شبرا': 'شبرا',
    'المطرية': 'المطرية',
    'عين شمس': 'عين شمس',
    'المطريه': 'المطرية',
    'الزيتون': 'الزيتون',
  };

  // محطات معروفة (للدمج)
  static final Set<String> _knownStops = _spellCorrections.values.toSet();

  /// تنظيف وتطبيع سلسلة المحطات
  static String normalize(String rawStops) {
    if (rawStops.isEmpty) return '';

    EgyptianLogger.d('تنظيف المحطات: $rawStops');

    var cleaned = rawStops
        // 1. توحيد الفواصل
        .replaceAll(_separators, ' . ')
        // 2. تنظيف النقاط المتعددة
        .replaceAll(RegExp(r'\.+'), '.')
        // 3. تنظيف المسافات
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // 4. تصحيح إملائي
    for (var entry in _spellCorrections.entries) {
      if (ratio(cleaned, entry.key) > 85) {
        cleaned = cleaned.replaceAll(entry.key, entry.value);
        EgyptianLogger.i('تم تصحيح: ${entry.key} → ${entry.value}');
      }
    }

    // 5. تنظيف نهائي
    cleaned = cleaned
        .replaceAll(RegExp(r'\s*\.\s*'), ' . ')
        .replaceAll(RegExp(r'^\s*\.\s*|\s*\.\s*$'), '')
        .trim();

    EgyptianLogger.i('تم تنظيف المحطات → $cleaned');
    return cleaned;
  }

  /// تقسيم المحطات إلى قائمة
  static List<String> split(String normalizedStops) {
    if (normalizedStops.isEmpty) return [];

    return normalizedStops
        .split(' . ')
        .map((s) => _cleanSingleStop(s))
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// تنظيف محطة واحدة
  static String _cleanSingleStop(String stop) {
    var cleaned = stop.trim();

    // إزالة الكلمات الزايدة
    for (var junk in _junkWords) {
      cleaned = cleaned.replaceAll(RegExp('\\b$junk\\b', caseSensitive: false), '');
    }

    // تنظيف المسافات الزايدة
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // إعادة إضافة "محطة" لو كانت معروفة
    if (_knownStops.any((known) => ratio(cleaned, known) > 90)) {
      final match = _knownStops.firstWhere(
        (known) => ratio(cleaned, known.replaceAll('محطة ', '')) > 90,
        orElse: () => cleaned,
      );
      cleaned = match;
    }

    return cleaned.isEmpty ? stop.trim() : cleaned;
  }

  /// دمج المحطات المتشابهة
  static List<String> deduplicate(List<String> stops) {
    final result = <String>[];
    final seen = <String>{};

    for (var stop in stops) {
      final normalized = stop.toLowerCase().trim();
      final similar = result.firstWhereOrNull(
        (s) => ratio(s.toLowerCase(), normalized) > 90,
      );

      if (similar == null) {
        result.add(stop);
        seen.add(normalized);
      }
    }

    if (stops.length != result.length) {
      EgyptianLogger.i('تم دمج ${stops.length - result.length} محطة متكررة');
    }

    return result;
  }

  /// معالجة كاملة لقائمة الخطوط
  static List<Map<String, dynamic>> processBusLines(
    List<Map<String, dynamic>> rawData,
  ) {
    final startTime = DateTime.now();
    var processedCount = 0;

    final result = rawData.map((line) {
      final updated = Map<String, dynamic>.from(line);
      final raw = updated['stops']?.toString() ?? '';

      if (raw.isEmpty) {
        updated['stops'] = '';
        updated['stops_list'] = <String>[];
        updated['stops_count'] = 0;
        return updated;
      }

      final normalized = normalize(raw);
      final splitList = split(normalized);
      final cleanList = deduplicate(splitList);

      updated['stops'] = normalized;
      updated['stops_list'] = cleanList;
      updated['stops_count'] = cleanList.length;
      updated['direction'] = _detectDirection(cleanList);

      processedCount++;
      return updated;
    }).toList();

    final duration = DateTime.now().difference(startTime);
    EgyptianLogger.performance('تنظيف $processedCount خط', duration);
    EgyptianLogger.palestine();

    return result;
  }

  /// كشف الاتجاه (ذهاب / عودة)
  static String _detectDirection(List<String> stops) {
    final first = stops.firstOrNull?.toLowerCase() ?? '';
    final last = stops.lastOrNull?.toLowerCase() ?? '';

    if (first.contains('رمسيس') && last.contains('المعادي')) return 'ذهاب';
    if (first.contains('المعادي') && last.contains('رمسيس')) return 'عودة';
    if (first.contains('التحرير') && last.contains('مدينة نصر')) return 'ذهاب';
    if (first.contains('مدينة نصر') && last.contains('التحرير')) return 'عودة';

    return stops.length > 10 ? 'ذهاب' : 'عودة';
  }

  /// إضافة فلسطين كمحطة رمزية
  static void addPalestineSupport(List<Map<String, dynamic>> data) {
    for (var line in data) {
      if (line['line_number'] == '1948') {
        line['stops_list'] = ['القدس', 'غزة', 'نابلس', 'حيفا', 'يافا', 'فلسطين حرة'];
        line['stops'] = 'القدس . غزة . نابلس . حيفا . يافا . فلسطين حرة';
        line['direction'] = 'من النهر إلى البحر';
      }
    }
    EgyptianLogger.i('تم تفعيل دعم فلسطين في الخط 1948');
  }

  /// إحصائيات
  static Map<String, dynamic> getStats(List<Map<String, dynamic>> data) {
    final totalLines = data.length;
    final totalStops = data.fold<int>(0, (sum, line) => sum + (line['stops_count'] as int? ?? 0));
    final duplicated = data.where((l) => (l['stops_list'] as List).length < (l['stops'] as String).split(' . ').length).length;

    return {
      'total_lines': totalLines,
      'total_stops': totalStops,
      'cleaned_lines': data.where((l) => l['stops_count'] > 0).length,
      'duplicates_removed': duplicated,
      'palestine_supported': data.any((l) => l['line_number'] == '1948'),
    };
  }
}