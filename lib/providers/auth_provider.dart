import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../pigeon.dart';

class AuthProvider extends ChangeNotifier {
  // ==================== الحالة ====================
  bool _isLoggedIn = false;
  String? _userId;
  String? _userEmail;
  String? _userName;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Firebase instances
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AuthApi _authApi;

  // Constructor for testing
  AuthProvider({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AuthApi? authApi,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _authApi = authApi ?? AuthApi();

  // Getters
  bool get isLoggedIn => _isLoggedIn;
  String? get userId => _userId;
  String? get userEmail => _userEmail;
  String get userName => _userName ?? 'مستخدم';
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  // مفتاح التخزين
  static const String _keyUserData = 'user_data';

  // ==================== أدوات مساعدة ====================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    _successMessage = null;
  }

  void _setError(String message) {
    _errorMessage = 'خطأ: $message';
    _successMessage = null;
    notifyListeners();
  }

  void _setSuccess(String message) {
    _successMessage = 'نجح: $message';
    _errorMessage = null;
    notifyListeners();
  }

  // ==================== SharedPreferences ====================
  Future<void> _saveUserToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = {
      'userId': _userId,
      'userEmail': _userEmail,
      'userName': _userName,
    };
    await prefs.setString(_keyUserData, json.encode(userData));
    await prefs.setBool('isLoggedIn', true);
  }

  Future<void> _clearPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserData);
    await prefs.setBool('isLoggedIn', false);
  }

  // ==================== Firestore ====================
  Future<void> _saveUserToFirestore(User user, String provider) async {
    await _firestore.collection('users').doc(user.uid).set({
      'name': user.displayName ?? 'مستخدم جديد',
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? '',
      'provider': provider,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLogin': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== تسجيل الدخول بالبريد/كلمة مرور ====================
  Future<void> login(String email, String password) async {
    _setLoading(true);
    _clearError();

    try {
      if (email.isEmpty || password.isEmpty) {
        throw 'برجاء إدخال البريد الإلكتروني وكلمة المرور';
      }

      final userCredential =
          await _auth.signInWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user!;
      _userId = user.uid;
      _userEmail = user.email;
      _userName = user.displayName ?? email.split('@').first;
      _isLoggedIn = true;

      await _saveUserToPrefs();
      await _saveUserToFirestore(user, 'email');
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'حدث خطأ في تسجيل الدخول');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ==================== التسجيل ====================
  Future<void> register(String email, String password, String name) async {
    _setLoading(true);
    _clearError();

    try {
      if (email.isEmpty || password.length < 6 || name.isEmpty) {
        throw 'تأكد من البيانات: الاسم، البريد، كلمة المرور (6 أحرف على الأقل)';
      }

      final userCredential =
          await _auth.createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user!;
      await user.updateDisplayName(name);

      _userId = user.uid;
      _userEmail = user.email;
      _userName = name;
      _isLoggedIn = true;

      await _saveUserToPrefs();
      await _saveUserToFirestore(user, 'email');
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'حدث خطأ في التسجيل');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ==================== تسجيل الخروج ====================
  Future<void> logout() async {
    _setLoading(true);

    try {
      // تسجيل الخروج من Firebase
      await _auth.signOut();
      
      _isLoggedIn = false;
      _userId = null;
      _userEmail = null;
      _userName = null;

      await _clearPrefs();
    } catch (e) {
      _setError('فشل تسجيل الخروج');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ==================== إعادة تعيين كلمة المرور ====================
  Future<void> resetPassword(String email) async {
    _setLoading(true);
    _clearError();

    try {
      if (!email.contains('@')) throw 'أدخل بريد إلكتروني صحيح';

      await _auth.sendPasswordResetEmail(email: email);
      _setSuccess('تم إرسال رابط إعادة التعيين إلى $email');
    } on FirebaseAuthException catch (e) {
      _setError(e.message ?? 'فشل إرسال رابط إعادة التعيين');
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  // ==================== Google Login ====================
  Future<void> loginWithGoogle() async {
    _setLoading(true);
    _clearError();

    try {
      final user = await _authApi.loginWithGoogle();
      if (user != null) {
        _userId = user.userId;
        _userEmail = user.email;
        _userName = user.name ?? user.email?.split('@').first;
        _isLoggedIn = true;

        await _saveUserToPrefs();
        // Since auth is in native, perhaps save to Firestore from native, but for now, assume we can get the user from Firebase Auth
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _saveUserToFirestore(currentUser, 'google');
        }
      } else {
        _setError('فشل تسجيل الدخول بجوجل');
      }
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }


  // ==================== التحقق من حالة الدخول عند بدء التطبيق ====================
  Future<void> checkLoginStatus() async {
    _setLoading(true);
    _clearError();

    try {
      final currentUser = _auth.currentUser;

      if (currentUser != null) {
        _userId = currentUser.uid;
        _userEmail = currentUser.email;
        _userName =
            currentUser.displayName ?? currentUser.email?.split('@').first;
        _isLoggedIn = true;

        await _saveUserToPrefs();
        await _saveUserToFirestore(currentUser, 'auto');
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        _isLoggedIn = false;
        _userId = null;
        _userEmail = null;
        _userName = null;
      }
    } catch (e) {
      _isLoggedIn = false;
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  // ==================== تنظيف الخطأ يدويًا ====================
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
