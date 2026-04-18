import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'dart:ui';
import 'package:enjaz7/services/firebase_messaging_service.dart' as fcm;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'auth/login_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_use_screen.dart';

class UltimateSettingsScreen extends StatefulWidget {
  final Function(bool)? onThemeChanged; // إضافة callback لتحديث السمة
  final Function(String)? onLanguageChanged; // إضافة callback لتحديث اللغة

  const UltimateSettingsScreen(
      {super.key, this.onThemeChanged, this.onLanguageChanged});

  @override
  State<UltimateSettingsScreen> createState() => _UltimateSettingsScreenState();
}

class _UltimateSettingsScreenState extends State<UltimateSettingsScreen>
    with TickerProviderStateMixin {
  bool _notificationsEnabled = true;
  bool _darkMode = false;
  bool _locationEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _dataSaver = false;
  bool _batterySaver = false;
  bool _egyptianVoice = false;
  String _language = 'العربية';
  // ignore: unused_field
  String _lastUpdate = 'منذ قليل';
  bool _isSaving = false;
  Color _primaryColor = Colors.blue;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    _loadSettings();
    _fadeController.forward();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
        _darkMode = prefs.getBool('dark_mode') ?? false;
        _locationEnabled = prefs.getBool('location_enabled') ?? true;
        _pushNotificationsEnabled =
            prefs.getBool('push_notifications_enabled') ?? true;
        _dataSaver = prefs.getBool('data_saver') ?? false;
        _batterySaver = prefs.getBool('battery_saver') ?? false;
        _egyptianVoice = prefs.getBool('egyptian_voice') ?? false;
        _language = prefs.getString('language') ?? 'العربية';
        _lastUpdate = prefs.getString('last_update') ?? 'منذ قليل';
        _primaryColor = Color(
          prefs.getInt('primary_color') ?? Colors.blue.value,
        );
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setBool('notifications_enabled', _notificationsEnabled),
      prefs.setBool('dark_mode', _darkMode),
      prefs.setBool('location_enabled', _locationEnabled),
      prefs.setBool('push_notifications_enabled', _pushNotificationsEnabled),
      prefs.setBool('data_saver', _dataSaver),
      prefs.setBool('battery_saver', _batterySaver),
      prefs.setBool('egyptian_voice', _egyptianVoice),
      prefs.setString('language', _language),
      prefs.setString(
        'last_update',
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
      ),
      prefs.setInt('primary_color', _primaryColor.value),
    ]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _language == 'English' ? 'Saved, Boss!' : 'تم الحفظ يا وحش!',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
    setState(() => _isSaving = false);
  }

  void _resetSettings() async {
    setState(() {
      _notificationsEnabled = true;
      _darkMode = false;
      _locationEnabled = true;
      _pushNotificationsEnabled = true;
      _dataSaver = false;
      _batterySaver = false;
      _egyptianVoice = false;
      _language = 'العربية';
    });
    await _saveSettings();
  }

  void _launchWhatsApp(String phoneNumber) async {
    final whatsappUrl = 'https://wa.me/$phoneNumber';
    final uri = Uri.parse(whatsappUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to whatsapp:// if https doesn't work
      final whatsappUri = Uri.parse('whatsapp://send?phone=$phoneNumber');
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isEn = _language == 'English';
    final theme = Theme.of(context).copyWith(
      primaryColor: _primaryColor,
      colorScheme: Theme.of(
        context,
      ).colorScheme.copyWith(primary: _primaryColor),
    );
    // isDark available from theme if needed in future

    return Theme(
      data: theme,
      child: Scaffold(
        body: Stack(
          children: [
            // Subtle background pattern
            Positioned.fill(
              child: Opacity(
                opacity: 0.03,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _primaryColor.withValues(alpha: 0.1),
                        Colors.transparent,
                        _primaryColor.withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            FadeTransition(
              opacity: _fadeAnimation,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 180,
                    floating: false,
                    pinned: true,
                    backgroundColor: _primaryColor,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Hero(
                            tag: 'settings_logo',
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: ColorFiltered(
                                  colorFilter: ColorFilter.mode(
                                    Colors.blue,
                                    BlendMode.srcIn,
                                  ),
                                  child: Image.asset(
                                    'assets/images/play_store_512.png',
                                    height: 35,
                                    width: 35,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                            _language == 'العربية' ? 'الإعدادات' : 'Settings',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black26,
                                  offset: Offset(0, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  _primaryColor,
                                  _primaryColor.withValues(alpha: 0.85),
                                  _primaryColor.withValues(alpha: 0.7),
                                ],
                              ),
                            ),
                          ),
                          // Glassmorphism effect
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                            child: Container(
                              color: Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      _buildSection(
                        title: isEn ? 'General' : 'العامة',
                        icon: Icons.settings_outlined,
                        children: [
                          _switchTile(
                            isEn ? 'Notifications' : 'الإشعارات',
                            isEn
                                ? 'Enable app notifications'
                                : 'تفعيل إشعارات التطبيق',
                            _notificationsEnabled,
                            (v) => setState(() => _notificationsEnabled = v),
                            _saveSettings,
                          ),
                          _switchTile(
                            isEn ? 'Dark Mode' : 'الوضع الداكن',
                            isEn ? 'Enable dark mode' : 'تفعيل الوضع الداكن',
                            _darkMode,
                            (v) {
                              setState(() => _darkMode = v);
                              widget.onThemeChanged
                                  ?.call(v); // استدعاء callback تحديث السمة
                            },
                            _saveSettings,
                          ),
                          _languageTile(isEn),
                          _switchTile(
                            isEn ? 'Egyptian Voice' : 'الصوت المصري',
                            isEn
                                ? 'Speak in authentic Egyptian accent'
                                : 'الكلام بلهجة مصرية أصيلة',
                            _egyptianVoice,
                            (v) => setState(() => _egyptianVoice = v),
                            _saveSettings,
                          ),
                        ],
                      ),
                      _buildSection(
                        title: isEn ? 'Savings' : 'التوفير',
                        icon: Icons.battery_saver_outlined,
                        children: [
                          _switchTile(
                            isEn ? 'Data Saver' : 'توفير الداتا',
                            isEn
                                ? 'Load maps on Wi-Fi only'
                                : 'تحميل الخرائط عند الواي فاي فقط',
                            _dataSaver,
                            (v) => setState(() => _dataSaver = v),
                            _saveSettings,
                          ),
                          _switchTile(
                            isEn ? 'Battery Saver' : 'توفير البطارية',
                            isEn
                                ? 'Reduce background updates'
                                : 'تقليل التحديثات في الخلفية',
                            _batterySaver,
                            (v) => setState(() => _batterySaver = v),
                            _saveSettings,
                          ),
                        ],
                      ),
                      _buildSection(
                        title: isEn ? 'Privacy' : 'الخصوصية',
                        icon: Icons.privacy_tip_outlined,
                        children: [
                          _switchTile(
                            isEn ? 'Location Service' : 'خدمة الموقع',
                            isEn
                                ? 'Allow location access'
                                : 'السماح بتحديد موقعك',
                            _locationEnabled,
                            (v) => setState(() => _locationEnabled = v),
                            _saveSettings,
                          ),
                          _switchTile(
                            isEn ? 'Push Notifications' : 'إشعارات الدفع',
                            isEn
                                ? 'Receive bus updates'
                                : 'تلقي تحديثات الحافلات',
                            _pushNotificationsEnabled,
                            (v) async {
                              setState(() => _pushNotificationsEnabled = v);
                              if (v) {
                                await fcm.FirebaseMessagingService
                                    .enablePushNotifications();
                              } else {
                                await fcm.FirebaseMessagingService
                                    .disablePushNotifications();
                              }
                              await _saveSettings();
                            },
                            () {}, // لا نحتاج لحفظ إضافي هنا
                          ),
                          _actionTile(
                            isEn ? 'Clear Search Data' : 'مسح بيانات البحث',
                            Icons.delete_outline,
                            () => _showClearDialog(isEn ? 'Search' : 'البحث'),
                          ),
                          _actionTile(
                            isEn ? 'Clear Cache' : 'مسح التخزين المؤقت',
                            Icons.cleaning_services_outlined,
                            () => _showClearDialog(
                                isEn ? 'Cache' : 'التخزين المؤقت'),
                          ),
                        ],
                      ),
                      _buildSection(
                        title: isEn ? 'App Information' : 'معلومات التطبيق',
                        icon: Icons.info_outline,
                        children: [
                          _infoTile(isEn ? 'Version' : 'الإصدار', '1.0.0+11'),
                          _linkTile(
                            isEn ? 'Privacy Policy' : 'سياسة الخصوصية',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PrivacyPolicyScreen()),
                            ),
                          ),
                          _linkTile(
                            isEn ? 'Terms of Use' : 'شروط الاستخدام',
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TermsOfUseScreen()),
                            ),
                          ),
                          _actionTile(
                            isEn
                                ? 'Contact us via WhatsApp'
                                : 'اتصل بنا عبر WhatsApp',
                            Icons.message_outlined,
                            () => _launchWhatsApp('+201234567890'),
                          ),
                          _actionTile(
                            isEn ? 'Logout' : 'تسجيل الخروج',
                            Icons.logout,
                            () async {
                              final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);
                              await authProvider.logout();
                              if (!context.mounted) return;
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen()),
                                (route) => false,
                              );
                            },
                            color: Colors.red,
                          ),
                          _actionTile(
                            isEn ? 'Reset Settings' : 'إعادة تعيين الإعدادات',
                            Icons.restart_alt_outlined,
                            _resetSettings,
                          ),
                        ],
                      ),
                      const SizedBox(height: 120),
                    ]),
                  ),
                ],
              ),
            ),

            // Saving Overlay
            if (_isSaving)
              Container(
                color: Colors.black.withValues(alpha: 0.6),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(32),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            strokeWidth: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              _primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          isEn ? 'Saving...' : 'جاري الحفظ...',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    Color? color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (color ?? _primaryColor).withValues(alpha: 0.1),
                        (color ?? _primaryColor).withValues(alpha: 0.05),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (color ?? _primaryColor).withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          icon,
                          color: color ?? _primaryColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: Colors.grey[800],
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _switchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
    VoidCallback onSave,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Switch(
              key: ValueKey(value),
              value: value,
              onChanged: (v) {
                onChanged(v);
                onSave();
              },
              activeColor: _primaryColor,
              activeTrackColor: _primaryColor.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageTile(bool isEn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: InkWell(
        onTap: () => showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              isEn ? 'Choose Language' : 'اختر اللهجة اللي تحبها',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _languageOption('العربية الفصحى', 'العربية', dialogContext),
                _languageOption('مصري عامي', 'مصري', dialogContext),
                _languageOption('English', 'English', dialogContext),
              ],
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.language, color: _primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEn ? 'Language' : 'اللغة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _language,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _languageOption(
    String title,
    String value,
    BuildContext dialogContext,
  ) {
    return RadioListTile<String>(
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[800]),
      ),
      value: value,
      groupValue: _language,
      onChanged: (v) => _updateLanguage(v!, dialogContext),
      activeColor: _primaryColor,
    );
  }

  void _updateLanguage(String lang, [BuildContext? dialogContext]) {
    setState(() => _language = lang);
    _saveSettings();
    widget.onLanguageChanged?.call(lang); // استدعاء callback تحديث اللغة
    if (dialogContext != null) {
      Navigator.pop(dialogContext);
    } else {
      Navigator.pop(context);
    }
  }

  Widget _infoTile(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
                letterSpacing: 0.2,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(String title, VoidCallback onTap) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Icon(Icons.open_in_new, size: 20, color: _primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(String title, IconData icon, VoidCallback onTap,
      {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[800],
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Icon(icon, size: 20, color: color ?? _primaryColor),
          ],
        ),
      ),
    );
  }

  void _showClearDialog(String type) {
    final isEn = _language == 'English';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isEn ? 'Clear $type' : 'مسح $type',
          style: TextStyle(color: _primaryColor, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isEn ? 'Are you sure?' : 'هل أنت متأكد؟',
          style: TextStyle(color: Colors.grey[700], fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isEn ? 'No' : 'لا',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isEn ? '$type cleared' : '$type تم مسحه'),
                  backgroundColor: _primaryColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              );
            },
            child: Text(
              isEn ? 'Yes' : 'أيوة',
              style: TextStyle(
                color: _primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
