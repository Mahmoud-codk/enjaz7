import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import '../models/stop.dart';
import 'station_translation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cache_service.dart'; // UltimateCacheService

class UltimateGeocodingService {
  static const String _cairo = 'القاهرة';
  static const String _egypt = 'مصر';
  static const Duration _cacheDuration = Duration(days: 30);

  // دعم Hive أو fallback في الذاكرة
  static dynamic _cacheBox;
  static bool _isInitialized = false;
  static Future<void>? _initFuture;

  // Cache for route-specific data from assets/data/bus_lines.json
  static List<dynamic>? _cachedBusLinesJson;

  /// تهيئة النظام (مرة واحدة)
  static Future<void> init() async {
    if (_isInitialized) return;
    if (_initFuture != null) return _initFuture!;
    _initFuture = _initImpl();
    await _initFuture;
  }

  static Future<void> _initImpl() async {
    await UltimateCacheService.init();

    try {
      final dir = await getApplicationDocumentsDirectory();
      Hive.init(dir.path);

      _cacheBox = await Hive.openBox('geocoding_cache');
      _isInitialized = true;
      debugPrint('تم فتح geocoding_cache بنجاح');
    } catch (e, s) {
      debugPrint('فشل فتح geocoding_cache: $e\n$s');

      // محاولة حذف الملفات التالفة
      try {
        final dir = await getApplicationDocumentsDirectory();
        final files = Directory(dir.path).listSync();

        for (var entity in files) {
          if (entity is File) {
            final name = entity.path.split('/').last;
            if (name.startsWith('geocoding_cache')) {
              await entity.delete();
              debugPrint('تم حذف ملف تالف: $name');
            }
          }
        }

        // إعادة المحاولة
        _cacheBox = await Hive.openBox('geocoding_cache');
        _isInitialized = true;
        debugPrint('تم إعادة إنشاء geocoding_cache بنجاح');
      } catch (e2, s2) {
        debugPrint('فشل إعادة الإنشاء، استخدام الذاكرة المؤقتة: $e2\n$s2');
        _cacheBox = _InMemoryBox();
        _isInitialized = true;
      }
    }
  }

  /// تحويل اسم المحطة → إحداثيات
  static Future<Stop?> smartGeocode(String rawInput) async {
    await init();

    final query = _preprocessEgyptianArabic(rawInput.trim());
    if (query.isEmpty) return null;

    String cacheKey = 'geocode_$query';
    // التحقق من طول المفتاح قبل استخدامه مع Hive
    if (cacheKey.length > 255) {
      cacheKey = cacheKey.substring(0, 255);
    }

    final prefs = await SharedPreferences.getInstance();
    final isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    final cached = _cacheBox.get(cacheKey);

    if (cached != null) {
      final time = cached['time'] as DateTime;
      if (DateTime.now().difference(time) < _cacheDuration) {
        final data = Map<String, dynamic>.from(cached['data']);
        final stop = Stop.fromMap(data);
        return isEn
            ? Stop(
                name: StationTranslationService().translate(stop.name),
                lat: stop.lat,
                lng: stop.lng)
            : stop;
      }
    }

    Stop? result;

    // 1. Try heuristic first for common Egyptian places (Fastest & Guaranteed)
    result = await _heuristicGeocode(rawInput); // Check raw input
    if (result == null) {
      result = await _heuristicGeocode(query); // Check processed query
    }

    // 2. Try Cache / External lookups if heuristic fails
    if (result == null) {
      result ??= await _googleGeocode(query);
      result ??= await _nominatimGeocode(query);

      if (result != null) {
        debugPrint(
            '🌐 API Result for "$query" => ${result.name} (${result.lat}, ${result.lng})');
      }
    }

    if (result != null && isEn) {
      result = Stop(
          name: StationTranslationService().translate(result.name),
          lat: result.lat,
          lng: result.lng);
    }

    if (result != null && areCoordinatesValid(result.lat, result.lng)) {
      await _cacheBox.put(cacheKey, {
        'data': result.toMap(),
        'time': DateTime.now(),
      });
    }

    return result;
  }

  /// معالجة العامية المصرية
  static String _preprocessEgyptianArabic(String input) {
    final corrections = {
      'تحت الكوبري': 'under the bridge',
      'قدام المسجد': 'in front of the mosque',
      'جنب المدرسة': 'next to the school',
      'عند النادي': 'at the club',
      'في الشارع الرئيسي': 'main street',
      'محطة المترو': 'metro station',
      'كوبري قصر النيل': 'Qasr El Nil Bridge',
      'ميدان التحرير': 'Tahrir Square',
      'رمسيس': 'Ramses',
      'العتبة': 'Ataba',
      'الدقي': 'Dokki',
      'مدينة نصر': 'Nasr City',
      'المعادي': 'Maadi',
      'حدائق القبة': 'Hadayek El Kobba',
    };

    String processed = input;
    corrections.forEach((arabic, english) {
      if (ratio(processed, arabic) > 80) {
        processed = processed.replaceAll(arabic, '$english, $_cairo');
      }
    });

    return '$processed, $_cairo, $_egypt';
  }

  static Future<Stop?> _googleGeocode(String query) async {
    try {
      final locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final address = await _reverseGeocode(loc.latitude, loc.longitude);
        debugPrint('✅ Google Geocoding found: $address');
        return Stop(
          name: address ?? query.split(',').first.trim(),
          lat: loc.latitude,
          lng: loc.longitude,
        );
      }
    } catch (_) {}
    // نترك المحاولة للـ Nominatim صمتاً
    return null;
  }

  static Future<Stop?> _nominatimGeocode(String query) async {
    try {
      final url =
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1&countrycodes=eg';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Enjaz7BusGuide/1.0 (+https://example.com)',
      });

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final item = data.first;
          final lat = double.parse(item['lat'].toString());
          final lng = double.parse(item['lon'].toString());
          final displayName = item['display_name'] as String;
          return Stop(
            name: _extractStopName(displayName),
            lat: lat,
            lng: lng,
          );
        }
      }
    } catch (e) {
      debugPrint('Nominatim فشل: $e');
    }
    return null;
  }

  static Future<Stop?> _heuristicGeocode(String query) async {
    final normalizedQuery = _normalizeArabic(query, stripped: true);
    final knownPlaces = _knownPlaces();

    for (var place in knownPlaces) {
      final normalizedName =
          _normalizeArabic(place['name'] as String, stripped: true);
      final normalizedKeywords =
          _normalizeArabic(place['keywords'] as String, stripped: true);

      final nameScore = ratio(normalizedQuery, normalizedName);
      final keywordMatch =
          normalizedKeywords.split(' ').any((k) => normalizedQuery.contains(k));
      final queryInName = normalizedName.contains(normalizedQuery) ||
          normalizedQuery.contains(normalizedName);

      if (nameScore > 75 || keywordMatch || queryInName) {
        debugPrint(
            '--- Match Found in Heuristics: "$query" -> "${place['name']}" (Score: $nameScore) ---');
        return Stop(
          name: place['name'] as String,
          lat: place['lat'] as double,
          lng: place['lng'] as double,
        );
      }
    }
    debugPrint('--- No Heuristic Match for "$query" ---');
    return null;
  }

  static String _normalizeArabic(String text, {bool stripped = false}) {
    String normalized = text.toLowerCase().trim();

    // Remove punctuation but keep Arabic characters, spaces, and numbers
    normalized =
        normalized.replaceAll(RegExp(r'[^\u0600-\u06FF\s0-9a-zA-Z]'), '');

    // Unify Alif
    normalized = normalized.replaceAll(RegExp(r'[أإآ]'), 'ا');

    // Unify Ta Marbuta
    normalized = normalized.replaceAll('ة', 'ه');

    // Unify Ya
    normalized = normalized.replaceAll('ى', 'ي');

    // Remove Harakat (Diacritics)
    normalized = normalized.replaceAll(RegExp(r'[\u064B-\u0652]'), '');

    if (stripped) {
      // Remove common prefix titles during matching to increase flexibility
      final titles = [
        'محطه',
        'موقف',
        'ميدان',
        'شارع',
        'ش ',
        'دوران',
        'كوبري',
        'بوابه',
        'ال'
      ];
      // Keep removing prefixes as long as there is a match (e.g., 'شارع ال' -> 'ال' -> '')
      bool changed = true;
      while (changed) {
        changed = false;
        for (var title in titles) {
          if (normalized.startsWith(title)) {
            normalized = normalized.replaceFirst(title, '').trim();
            changed = true;
            break;
          }
        }
      }
    }

    return normalized;
  }

  static List<Map<String, dynamic>> _knownPlaces() => [
        {
          'name': 'ميدان التحرير',
          'keywords': 'تحرير تظاهر',
          'lat': 30.0444,
          'lng': 31.2357
        },
        {
          'name': 'رمسيس',
          'keywords': 'رمسيس محطة قطار',
          'lat': 30.0635,
          'lng': 31.2469
        },
        {
          'name': 'العتبة',
          'keywords': 'عتبة سوق',
          'lat': 30.0522,
          'lng': 31.2463
        },
        {
          'name': 'كوبري قصر النيل',
          'keywords': 'قصر النيل كوبري',
          'lat': 30.0434,
          'lng': 31.2296
        },
        {
          'name': 'مدينة نصر',
          'keywords': 'نصر ستاد',
          'lat': 30.0511,
          'lng': 31.3378
        },
        {
          'name': 'المعادي',
          'keywords': 'معادي كورنيش',
          'lat': 29.9701,
          'lng': 31.2501
        },
        {
          'name': 'الالف مسكن',
          'keywords': 'ألف مسكن جسر السويس',
          'lat': 30.1215,
          'lng': 31.3418
        },
        {
          'name': 'التجنيد',
          'keywords': 'تجنيد حلمية زيتون',
          'lat': 30.1105,
          'lng': 31.3323
        },
        {
          'name': 'المطرية',
          'keywords': 'مطرية مسلة',
          'lat': 30.1305,
          'lng': 31.3142
        },
        {
          'name': 'مسطرد',
          'keywords': 'ترعة الإسماعيلية مسطرد',
          'lat': 30.1437,
          'lng': 31.3101
        },
        {
          'name': 'شارع اللبيني',
          'keywords': 'لبيني هرم فيصل',
          'lat': 29.9912,
          'lng': 31.1444
        },
        {
          'name': 'موقف العاشر',
          'keywords': 'عاشر مدينة السلام',
          'lat': 30.1587,
          'lng': 31.4259
        },
        {
          'name': 'جسر السويس',
          'keywords': 'جسر سويس الف مسكن',
          'lat': 30.1264,
          'lng': 31.3506
        },
        {
          'name': 'حلمية الزيتون',
          'keywords': 'حلمية زيتون تجنيد',
          'lat': 30.1167,
          'lng': 31.3167
        },
      ];

  static String _extractStopName(String displayName) {
    return displayName.split(',').first.trim();
  }

  static Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.street ?? ''} ${p.subLocality ?? ''} ${p.locality ?? ''}'
            .trim();
      }
    } catch (e) {
      debugPrint('Reverse Geocode فشل: $e');
    }
    return null;
  }

  static Future<List<Stop>> smartGeocodeMultiple(List<String> names,
      {String? routeNumber}) async {
    final results = <Stop>[];
    debugPrint('--- بدء جلب إحداثيات الخط $routeNumber ---');
    debugPrint('عدد المحطات المطلوب جلبها: ${names.length}');

    final prefs = await SharedPreferences.getInstance();
    final isEn = (prefs.getString('language') ?? 'العربية') == 'English';

    // 1. Try to fetch route-specific coordinates from bus_lines.json first
    Map<String, Stop>? routeStopsMap;
    if (routeNumber != null) {
      routeStopsMap = await getRouteSpecificCoordinates(routeNumber);
    }

    if (routeStopsMap != null) {
      debugPrint(
          'بيانات الخط $routeNumber متوفرة. عدد النقط: ${routeStopsMap.length}');
    } else {
      debugPrint('لم يتم العثور على الخط $routeNumber في قاعدة البيانات.');
    }

    for (var name in names) {
      Stop? stop;

      // 2. Look in route-specific map if available
      if (routeStopsMap != null) {
        final normalizedName = _normalizeArabic(name, stripped: true);
        stop = routeStopsMap[normalizedName];

        if (stop == null) {
          String? bestKey;
          int bestScore = 0;
          for (var key in routeStopsMap.keys) {
            final score = ratio(normalizedName, key);
            if (score > 75 && score > bestScore) {
              bestScore = score;
              bestKey = key;
            }
          }
          if (bestKey != null) {
            stop = routeStopsMap[bestKey];
            debugPrint(
                'مطابقة التقريبية لـ "$name" ← "${stop?.name}" ($bestScore%)');
          }
        } else {
          debugPrint('✅ [DB] مطابقة تامة: "$name"');
        }
      }

      // 3. Fallback to smartGeocode (Heuristics -> Google -> Nominatim)
      if (stop == null) {
        debugPrint('🔍 بحث خارجي لـ "$name"...');
        stop = await smartGeocode(name);
        if (stop != null) debugPrint('✨ تم العثور (الخريطة) لـ "$name"');
      }

      final finalStop = stop ?? Stop(name: name, lat: 0.0, lng: 0.0);
      results.add(isEn
          ? Stop(
              name: StationTranslationService().translate(finalStop.name),
              lat: finalStop.lat,
              lng: finalStop.lng)
          : finalStop);

      if (stop == null) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    final validCount =
        results.where((s) => areCoordinatesValid(s.lat, s.lng)).length;
    debugPrint(
        '--- انتهى جلب الإحداثيات. محطات صالحة: $validCount من أصل ${names.length} ---');

    return results;
  }

  /// Fetches coordinates for a specific route from the project's bus_lines.json asset
  static Future<Map<String, Stop>?> getRouteSpecificCoordinates(
      String routeNumber) async {
    try {
      if (_cachedBusLinesJson == null) {
        final jsonString =
            await rootBundle.loadString('assets/data/bus_lines.json');
        _cachedBusLinesJson = json.decode(jsonString);
        debugPrint('تم تحميل قاعدة بيانات مسارات الباصات بنجاح');
      }

      final normalizedRoute = routeNumber.trim().toUpperCase();

      // Collect ALL matching route entries (Go, Return, variants)
      final allEntries = _cachedBusLinesJson
          ?.where(
            (line) =>
                line['routeNumber'].toString().trim().toUpperCase() ==
                normalizedRoute,
          )
          .toList();

      if (allEntries != null && allEntries.isNotEmpty) {
        final Map<String, Stop> stopsMap = {};
        for (var entry in allEntries) {
          final stops = entry['stops'] as List;
          for (var s in stops) {
            final stopName = s['name'].toString();
            final norm = _normalizeArabic(stopName, stripped: true);
            // Always prefer entry with valid coordinates
            if (!stopsMap.containsKey(norm) || stopsMap[norm]?.lat == 0.0) {
              stopsMap[norm] = Stop(
                name: stopName,
                lat: double.tryParse(s['lat'].toString()) ?? 0.0,
                lng: double.tryParse(s['lng'].toString()) ?? 0.0,
              );
            }
          }
        }
        return stopsMap;
      }
    } catch (e) {
      debugPrint('خطأ أثناء قراءة إحداثيات الخط $routeNumber: $e');
    }
    return null;
  }

  static Future<Position?> getCurrentLocation(
      {bool highAccuracy = true}) async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy:
            highAccuracy ? LocationAccuracy.best : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20),
      );
    } catch (e) {
      debugPrint('خطأ في جلب الموقع: $e');
      return null;
    }
  }

  static bool areCoordinatesValid(double lat, double lng) {
    return lat != 0.0 &&
        lng != 0.0 &&
        lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  static Future<Stop> getPalestineStop() async {
    return Stop(name: 'فلسطين حرة', lat: 31.9474, lng: 35.2272);
  }

  static Future<void> clearCache() async {
    await init();
    await _cacheBox.clear();
  }
}

/// تنظيف تلقائي عند بدء التطبيق
Future<void> ensureGeocodingCacheHealthy() async {
  try {
    await UltimateGeocodingService.init();
  } catch (e, s) {
    debugPrint('تنظيف تلقائي للكاش: $e\n$s');
  }
}

/// Fallback في الذاكرة إذا فشل Hive تمامًا
class _InMemoryBox {
  final Map<String, dynamic> _store = {};

  dynamic get(String key, {dynamic defaultValue}) =>
      _store.containsKey(key) ? _store[key] : defaultValue;

  Future<void> put(String key, dynamic value) async => _store[key] = value;

  Future<void> clear() async => _store.clear();

  Iterable<String> get keys => _store.keys;
}
