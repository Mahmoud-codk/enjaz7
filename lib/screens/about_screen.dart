import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
  }

  Future<void> _loadAppInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('لا يمكن فتح الرابط: $url');
    }
  }

  Future<void> _rateApp() async {
    const playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.busguide.cairo';
    await _launchUrl(playStoreUrl);
  }

  Future<void> _shareApp() async {
    await SharePlus.instance.share(ShareParams(
      text: 'جرب تطبيق دليل حافلات القاهرة - أفضل طريقة للتنقل في القاهرة!\n'
          'حمّله الآن: https://play.google.com/store/apps/details?id=com.busguide.cairo',
      subject: 'تطبيق دليل حافلات القاهرة',
    ));
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Hero(
              tag: 'app_logo',
              child: Image.asset(
                'assets/images/play_store_512.png',
                height: 40,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'عن التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareApp,
            tooltip: 'مشاركة التطبيق',
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isDark
                  ? [Colors.grey[900]!, Colors.black]
                  : [Colors.blue[50]!, Colors.white],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 100, 16, 32),
            child: Column(
              children: [
                // Logo + Title
                Hero(
                  tag: 'app_logo_large',
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/play_store_512.png',
                      height: 120,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'دليل حافلات القاهرة',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'الإصدار $_appVersion (البناء $_buildNumber)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),

                // About Card
                _buildGlassCard(
                  context,
                  title: 'عن التطبيق',
                  icon: Icons.info_outline,
                  child: const Text(
                    'دليل حافلات القاهرة هو تطبيق شامل يساعدك في العثور على خطوط الحافلات وحافلات الميني باص في القاهرة الكبرى. يوفر التطبيق معلومات عن جميع الخطوط والمحطات ليسهل عليك التنقل في المدينة بسهولة وسرعة.',
                    style: TextStyle(fontSize: 16, height: 1.6),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Features Card
                _buildGlassCard(
                  context,
                  title: 'المميزات الرئيسية',
                  icon: Icons.star_border,
                  child: Column(
                    children: [
                      _featureTile(Icons.search, 'البحث السريع عن الخطوط'),
                      _featureTile(Icons.location_on, 'عرض المحطات على الخريطة'),
                      _featureTile(Icons.favorite, 'حفظ الخطوط المفضلة'),
                      _featureTile(Icons.offline_pin, 'يعمل بدون إنترنت'),
                      _featureTile(Icons.update, 'تحديثات يومية للخطوط'),
                      _featureTile(Icons.share, 'مشاركة الخطوط مع الأصدقاء'),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Contact Card
                _buildGlassCard(
                  context,
                  title: 'تواصل معنا',
                  icon: Icons.contact_mail,
                  child: Column(
                    children: [
                      _contactTile(
                        icon: Icons.email,
                        title: 'البريد الإلكتروني',
                        subtitle: '7oda.sala7.2030@busguide.com',
                        onTap: () => _launchUrl(
                            'mailto:7oda.sala7.2030@busguide.com?subject=استفسار من تطبيق دليل حافلات القاهرة'),
                      ),
                      _contactTile(
                        icon: Icons.public,
                        title: 'الموقع الرسمي',
                        subtitle: 'www.busguide.com',
                        onTap: () => _launchUrl('https://www.busguide.com'),
                      ),
                      _contactTile(
                        icon: FontAwesomeIcons.facebook,
                        title: 'فيسبوك',
                        subtitle: 'دليل حافلات القاهرة',
                        onTap: () => _launchUrl('https://facebook.com/busguide'),
                      ),
                      _contactTile(
                        icon: FontAwesomeIcons.twitter,
                        title: 'تويتر',
                        subtitle: '@busguide',
                        onTap: () => _launchUrl('https://twitter.com/busguide'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Rate & Share Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _rateApp,
                      icon: const Icon(Icons.star),
                      label: const Text('قيّم التطبيق'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: _shareApp,
                      icon: const Icon(Icons.share),
                      label: const Text('مشاركة'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Text(
                  'جميع الحقوق محفوظة © 2025 دليل حافلات القاهرة',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'صُنع بحب في مصر',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassCard(BuildContext context, {
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _featureTile(IconData icon, String text) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(text, style: const TextStyle(fontSize: 16)),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue[700]),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}