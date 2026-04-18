import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/bus_line.dart';

class FavoritesProvider extends ChangeNotifier {
  // ==================== الحالة ====================
  static const String _boxName = 'favorites_box';
  static const String _favoritesKey = 'favorites_list';
  static const int maxFavorites = 20; // حد أقصى للمفضلات

  Box? _box;
  final List<BusLine> _favorites = []; // استخدم List بدلاً من Set
  bool _isLoading = true;
  String? _errorMessage;

  // Getters
  List<BusLine> get favorites => List.unmodifiable(_favorites);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get count => _favorites.length;

  // ==================== Constructor ====================
  final bool _testMode;

  FavoritesProvider({bool testMode = false}) : _testMode = testMode {
    if (!_testMode) {
      _initHive();
    } else {
      // In test mode, keep favorites empty
      _isLoading = false;
    }
  }

  Future<void> _initHive() async {
    try {
      _box = await Hive.openBox(_boxName);
      debugPrint('✅ تم فتح صندوق Hive: $_boxName');
      await _loadFavorites();
    } catch (e) {
      _setError('فشل تهيئة Hive: $e');
      debugPrint('❌ Hive init error: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  // ==================== تحميل المفضلات ====================
  Future<void> _loadFavorites() async {
    _setLoading(true);
    _clearError();

    try {
      // حاول التحميل من Hive مباشرة من القيم
      try {
        if (_box == null) _box = await Hive.openBox(_boxName);
        final List<dynamic> savedItems = _box!.values.toList();
        if (savedItems.isNotEmpty) {
          _favorites.clear();
          int successCount = 0;
          for (var item in savedItems) {
            try {
              if (item is BusLine) {
                _favorites.add(item);
                successCount++;
              }
            } catch (e) {
              debugPrint('⚠️ فشل تحميل عنصر من Hive: $e');
            }
          }
          debugPrint('✅ تم تحميل $successCount من ${savedItems.length} مفضلة من Hive');
        } else {
          debugPrint('⚠️ صندوق Hive فارغ، محاولة تحميل النسخة الاحتياطية');
          await _loadFromBackup();
        }
      } catch (e) {
        debugPrint('⚠️ فشل تحميل من Hive: $e، محاولة النسخة الاحتياطية');
        await _loadFromBackup();
      }
    } catch (e, stackTrace) {
      _setError('فشل تحميل المفضلات: $e');
      debugPrint('❌ Favorites load error: $e\n$stackTrace');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _loadFromBackup() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final backupString = prefs.getString('favorite_bus_lines_backup');
      
      if (backupString != null && backupString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(backupString);
        
        final List<BusLine> loaded = [];
        int successCount = 0;
        for (var jsonItem in jsonList) {
          try {
            final map = Map<String, dynamic>.from(jsonItem);
            final busLine = BusLine.fromMap(map);
            loaded.add(busLine);
            successCount++;
          } catch (e) {
            debugPrint('فشل تحميل خط من النسخة الاحتياطية: $e');
          }
        }
        
        if (loaded.isNotEmpty) {
          _favorites.clear();
          _favorites.addAll(loaded);
          // احفظها في Hive أيضاً
          await _saveFavorites();
          debugPrint('✅ تم تحميل $successCount من ${jsonList.length} مفضلة من النسخة الاحتياطية');
        }
      } else {
        debugPrint('⚠️ لا توجد نسخة احتياطية أيضاً');
        // Migrate from SharedPreferences if no data in Hive
        await _migrateFromSharedPreferences();
      }
    } catch (e) {
      debugPrint('❌ خطأ تحميل النسخة الاحتياطية: $e');
    }
  }

  Future<void> _migrateFromSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesString = prefs.getString('favorite_bus_lines_v2');

      if (favoritesString != null && favoritesString.isNotEmpty) {
        final List<dynamic> jsonList = json.decode(favoritesString);

        final List<BusLine> loaded = [];
        for (var jsonItem in jsonList) {
          try {
            final map = Map<String, dynamic>.from(jsonItem);
            final busLine = BusLine.fromMap(map);
            loaded.add(busLine);
          } catch (e) {
            debugPrint('فشل تحميل خط باص من المفضلة أثناء الترحيل: $e');
          }
        }

        _favorites.clear();
        _favorites.addAll(loaded);

        // Save to Hive
        await _saveFavorites();

        // Optionally clear old SharedPreferences
        // await prefs.remove('favorite_bus_lines_v2');

        debugPrint('تم ترحيل ${loaded.length} خط من SharedPreferences إلى Hive');
      }
    } catch (e) {
      debugPrint('فشل الترحيل من SharedPreferences: $e');
    }
  }

  // ==================== حفظ المفضلات ====================
  Future<void> _saveFavorites() async {
    if (_testMode) return;
    try {
      // احفظ في Hive مباشرة
      final List<BusLine> favoritesList = List.from(_favorites);
      
      debugPrint('⏳ جاري حفظ ${favoritesList.length} مفضلة في Hive...');
      
      if (_box == null) _box = await Hive.openBox(_boxName);
      
      // حفظ صريح في Hive
      await _box!.clear(); // امسح أولاً
      await _box!.addAll(favoritesList); // أضف الجديدة
      
      // انتظر قليلاً
      await Future.delayed(Duration(milliseconds: 50));
      
      // تحقق من أن البيانات تم حفظها
      final savedCount = _box!.values.length;
      debugPrint('✅ تم حفظ ${savedCount} مفضلة في Hive');
      
      if (savedCount != favoritesList.length) {
        debugPrint('⚠️ تحذير: عدد العناصر المحفوظة (${savedCount}) ≠ عدد المفضلات (${favoritesList.length})');
      }
      
      // حفظ نسخة احتياطية في SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        final jsonList = json.encode(
          favoritesList.map((bus) => bus.toMap()).toList(),
        );
        await prefs.setString('favorite_bus_lines_backup', jsonList);
        
        debugPrint('✅ تم حفظ نسخة احتياطية في SharedPreferences (${favoritesList.length} عنصر)');
      } catch (e) {
        debugPrint('⚠️ فشل حفظ النسخة الاحتياطية: $e');
      }
      
    } catch (e, stackTrace) {
      _setError('فشل حفظ المفضلات: $e');
      debugPrint('❌ Favorites save error: $e\n$stackTrace');
      rethrow;
    }
  }

  // ==================== التحقق من المفضلة ====================
  bool isFavorite(BusLine busLine) {
    // نستخدم == اللي عملناه في BusLine (يعتمد على routeNumber + type)
    return _favorites.any((fav) => fav == busLine);
  }

  // ==================== التحقق من الحد الأقصى ====================
  bool isMaxFavoritesReached() {
    return _favorites.length >= maxFavorites;
  }

  int getRemainingFavoritesSlots() {
    return maxFavorites - _favorites.length;
  }

  // ==================== إضافة إلى المفضلة ====================
  Future<void> addFavorite(BusLine busLine) async {
    if (busLine.routeNumber.isEmpty) {
      _setError('لا يمكن إضافة خط بدون رقم');
      return;
    }

    // فحص الحد الأقصى
    if (_favorites.length >= maxFavorites) {
      _setError('وصلت إلى الحد الأقصى من المفضلات ($maxFavorites)');
      debugPrint('❌ محاولة إضافة أكثر من $maxFavorites مفضلات');
      return;
    }

    // تحقق من عدم التكرار باستخدام routeNumber فقط
    final alreadyExists = _favorites.any((fav) => fav.routeNumber == busLine.routeNumber);

    if (!alreadyExists) {
      _favorites.add(busLine);
      debugPrint('✅ أضيف الخط ${busLine.routeNumber} للقائمة (الإجمالي: ${_favorites.length})');
      
      // احفظ مباشرة بدون انتظار
      _saveFavoritesSync(); // احفظ متزامن
      
      // احفظ async أيضاً
      unawaited(_saveFavorites());
      
      notifyListeners();
    } else {
      _setError('هذا الخط موجود بالفعل في المفضلة');
      debugPrint('⚠️ الخط ${busLine.routeNumber} موجود بالفعل');
    }
  }

  /// حفظ متزامن للتأكد من الحفظ الفوري
  void _saveFavoritesSync() {
    try {
      if (_box == null) return;
      final List<BusLine> favoritesList = List.from(_favorites);
      _box!.clear();
      _box!.addAll(favoritesList);
      debugPrint('💾 تم حفظ متزامن ${favoritesList.length} مفضلة');
    } catch (e) {
      debugPrint('❌ فشل الحفظ المتزامن: $e');
    }
  }

  void unawaited(Future<void> future) {
    // تجاهل نتيجة المستقبل
    future.ignore();
  }

  // ==================== إزالة من المفضلة ====================
  Future<void> removeFavorite(BusLine busLine) async {
    final index = _favorites.indexWhere((fav) => fav.routeNumber == busLine.routeNumber);
    if (index != -1) {
      final removed = _favorites.removeAt(index);
      debugPrint('✅ تم حذف الخط ${removed.routeNumber} من المفضلة (الإجمالي: ${_favorites.length})');
      
      // احفظ مباشرة بدون انتظار
      _saveFavoritesSync();
      
      // احفظ async أيضاً
      unawaited(_saveFavorites());
      
      notifyListeners();
    }
  }

  // ==================== تبديل الحالة ====================
  Future<void> toggleFavorite(BusLine busLine) async {
    if (isFavorite(busLine)) {
      await removeFavorite(busLine);
    } else {
      await addFavorite(busLine);
    }
  }

  // ==================== مسح الكل ====================
  Future<void> clearAllFavorites() async {
    if (_favorites.isEmpty) return;

    final count = _favorites.length;
    _favorites.clear();
    debugPrint('✅ تم حذف $count مفضلة');
    await _saveFavorites();
    notifyListeners();
    _setError('تم مسح جميع المفضلات', isSuccess: true);
  }

  // ==================== تحديث الاستخدام ====================
  Future<void> updateFavorite(BusLine busLine) async {
    final index = _favorites.indexWhere((fav) => fav.routeNumber == busLine.routeNumber);
    if (index != -1) {
      final updated = busLine.copyWith(
        lastUsed: DateTime.now(),
        usageCount: (busLine.usageCount ?? 0) + 1,
      );
      _favorites[index] = updated;
      await _saveFavorites();
      notifyListeners();
      debugPrint('✅ تم تحديث الخط ${busLine.routeNumber}');
    }
  }

  // ==================== البحث في المفضلات ====================
  List<BusLine> search(String query) {
    if (query.isEmpty) return favorites;

    final lowerQuery = query.toLowerCase();
    return _favorites.where((bus) {
      return bus.routeNumber.toLowerCase().contains(lowerQuery) ||
          bus.type.toLowerCase().contains(lowerQuery) ||
          bus.stops.any((s) => s.toLowerCase().contains(lowerQuery));
    }).toList();
  }

  // ==================== أدوات مساعدة ====================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  void _setError(String message, {bool isSuccess = false}) {
    _errorMessage = isSuccess ? 'نجح: $message' : 'خطأ: $message';
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== للـ debug فقط ====================
  void printAllFavorites() {
    if (kDebugMode) {
      debugPrint('=== المفضلات (${_favorites.length}) ===');
      for (var bus in _favorites) {
        debugPrint('• ${bus.routeNumber} | ${bus.type} | مقاعد فاضية: ${bus.emptySeats}');
      }
    }
  }

  // ==================== مزامنة البيانات ====================
  /// تأكد من حفظ جميع البيانات فورًا (مهم عند إغلاق التطبيق)
  Future<void> ensureDataSaved() async {
    if (!_testMode) {
      try {
        // اجبر على الحفظ
        await _saveFavorites();
        
        // انتظر قليلاً للتأكد من اكتمال العملية
        await Future.delayed(Duration(milliseconds: 100));
        
        // حاول الـ flush مجدداً للتأكد
        try {
          if (_box != null) {
            await _box!.flush();
            debugPrint('✅ تم فرض flush على Hive');
          }
        } catch (e) {
          debugPrint('⚠️ فشل flush على Hive: $e');
        }
        
        // التحقق من أن البيانات محفوظة بالفعل
        if (_box != null) {
          final boxValues = _box!.values.toList();
          debugPrint('✅ تم التأكد من حفظ المفضلات بنجاح (${boxValues.length} خط في Hive)');
        }
        
        // تأكيد أيضاً في SharedPreferences
        try {
          final prefs = await SharedPreferences.getInstance();
          final backupString = prefs.getString('favorite_bus_lines_backup');
          if (backupString != null && backupString.isNotEmpty) {
            debugPrint('✅ تم التأكد من وجود نسخة احتياطية في SharedPreferences');
          }
        } catch (e) {
          debugPrint('⚠️ فشل التحقق من النسخة الاحتياطية: $e');
        }
        
      } catch (e) {
        debugPrint('❌ خطأ في حفظ المفضلات: $e');
        rethrow;
      }
    }
  }
}
