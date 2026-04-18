// app_drawer.dart
import 'package:flutter/material.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import '../screens/auth/login_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/settings_screen.dart' show UltimateSettingsScreen;
import '../screens/about_screen.dart';
import '../screens/history_screen.dart';
import '../screens/whatsapp_chat_screen.dart';
import '../utils/ultimate_url_launcher.dart';

class UltimateAppDrawer extends StatefulWidget {
  const UltimateAppDrawer({super.key});

  @override
  State<UltimateAppDrawer> createState() => _UltimateAppDrawerState();
}

class _UltimateAppDrawerState extends State<UltimateAppDrawer> {
  final ConfettiController _confettiController = ConfettiController();
  String userName = 'مستخدم';
  String userPhone = '';
  int favoriteCount = 0;
  int historyCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userName = prefs.getString('user_name') ?? 'يا وحش';
      userPhone = prefs.getString('user_phone') ?? '';
      favoriteCount = prefs.getStringList('favorites')?.length ?? 0;
      historyCount = prefs.getStringList('search_history')?.length ?? 0;
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'صباح الخير';
    if (hour < 18) return 'مساء الخير';
    return 'تصبح على خير';
  }

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد؟ هتفتقدنا؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('لأ')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('أيوة', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      _confettiController.play();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                margin: EdgeInsets.zero,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: isDark
                        ? [const Color(0xFF0D47A1), const Color(0xFF1976D2)]
                        : [const Color(0xFF1565C0), const Color(0xFF42A5F5)],
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Image.asset(
                            'assets/images/egypt_flag.png',
                            height: 28,
                            errorBuilder: (_, __, ___) => const Icon(Icons.flag,
                                color: Colors.red, size: 28),
                          ),
                          const SizedBox(width: 8),
                          Image.asset(
                            'assets/images/palestine_flag.png',
                            height: 28,
                            errorBuilder: (_, __, ___) => const Icon(Icons.flag,
                                color: Colors.green, size: 28),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_getGreeting()}، $userName!',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                      ),
                      if (userPhone.isNotEmpty)
                        Text(
                          userPhone,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      const SizedBox(height: 4),
                      const Text(
                        'دليل حافلات انجاز',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              // Animation
              SizedBox(
                height: 80,
                child: Lottie.asset('assets/animations/bus_drive.json'),
              ),

              ListTile(
                leading: const Icon(Icons.home, color: Colors.blue),
                title: const Text('الرئيسية'),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.favorite, color: Colors.red),
                title: const Text('المفضلة'),
                trailing: favoriteCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.red,
                        child: Text('$favoriteCount',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const FavoritesScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.orange),
                title: const Text('سجل البحث'),
                trailing: historyCount > 0
                    ? CircleAvatar(
                        radius: 12,
                        backgroundColor: Colors.orange,
                        child: Text('$historyCount',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white)),
                      )
                    : null,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()));
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('الإعدادات'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const UltimateSettingsScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.info),
                title: const Text('عن التطبيق'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const AboutScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Colors.green),
                title: const Text('دردشة واتساب'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const WhatsAppChatScreen()));
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('شارك التطبيق'),
                onTap: () {
                  UltimateLinkLauncher.share(
                    'جرب دليل حافلات إنجاز - أحسن تطبيق مواصلات في مصر!',
                    url:
                        'https://play.google.com/store/apps/details?id=com.enjaz.busguide',
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('إنجاز باص جايد'),
                onTap: () {
                  UltimateLinkLauncher.share(
                    'جرب تطبيق إنجاز باص جايد - دليل شامل للحافلات في مصر!',
                    url:
                        'https://play.google.com/store/apps/details?id=com.enjaz.busguide',
                  );
                },
              ),

              ListTile(
                leading: const Icon(Icons.star_rate, color: Colors.amber),
                title: const Text('قيّم التطبيق'),
                onTap: () => UltimateLinkLauncher.open(Platform.isAndroid
                    ? 'market://details?id=com.enjaz.busguide'
                    : 'https://play.google.com/store/apps/details?id=com.enjaz.busguide'),
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('تسجيل الخروج',
                    style: TextStyle(color: Colors.red)),
                onTap: () => _logout(context),
              ),
            ],
          ),

          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: const [
                Colors.red,
                Colors.white,
                Colors.green,
                Colors.black
              ],
              emissionFrequency: 0.05,
              numberOfParticles: 30,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }
}
