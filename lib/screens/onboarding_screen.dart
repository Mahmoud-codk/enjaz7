import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, dynamic>> _pages = [
    {
      'title': 'كل الخيارات أمامك',
      'subtitle':
          'اعرف أرقام الميني باص والباصات،\nواختر الأنسب للوصول بسرعة.',
      'icon': Icons.directions_bus_filled_rounded,
    },
    {
      'title': 'كل خط واضح',
      'subtitle':
          'كل خط ووسيلة نقل موضحة بوضوح،\nعلشان تختار طريقك بثقة.',
      'icon': Icons.route,
    },
    {
      'title': 'ابحث بين نقطتين فقط',
      'subtitle':
          'اكتب نقطة الانطلاق ونقطة الوصول،\nودع التطبيق يقترح أفضل الخطوط.',
      'icon': Icons.search_rounded,
    },
    {
      'title': 'هيا نبدأ!',
      'subtitle':
          'ابدأ رحلتك الآن واضغط "ابدأ"،\nوالطريق بقى أسهل من أي وقت.',
      'icon': Icons.waving_hand_rounded,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // خلفية مودرن gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0D47A1),
                  const Color(0xFF1976D2),
                  Colors.white.withOpacity(0.4),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // زر التخطي في الأعلى يمين
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextButton(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                      ),
                      child: const Text(
                        'تخطي',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),

                // الصفحات نفسها
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) => setState(() => _currentPage = index),
                    itemCount: _pages.length,
                    itemBuilder: (context, index) {
                      return _buildModernPage(_pages[index], index);
                    },
                  ),
                ),

                // الـ Indicator + الزر تحت
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Page Indicator مودرن
                      SmoothPageIndicator(
                        controller: _pageController,
                        count: _pages.length,
                        effect: const WormEffect(
                          dotHeight: 10,
                          dotWidth: 10,
                          spacing: 16,
                          activeDotColor: Colors.white,
                          dotColor: Colors.white54,
                        ),
                      ),

                      // زر التالي / ابدأ مودرن
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            if (_currentPage == _pages.length - 1) {
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('hasSeenOnboarding', true);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => const HomeScreen()),
                              );
                            } else {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 600),
                                curve: Curves.easeInOutCubic,
                              );
                            }
                          },
                          icon: Icon(
                            _currentPage == _pages.length - 1
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            _currentPage == _pages.length - 1 ? 'ابدأ الآن' : 'التالي',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1976D2),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                            elevation: 10,
                            shadowColor: const Color(0xFF1976D2).withOpacity(0.4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPage(Map<String, dynamic> page, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // أيقونة كبيرة مودرن بدائرة شفافة
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1976D2).withOpacity(0.3),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: Icon(
              page['icon'] as IconData,
              size: 90,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 48),

          // العنوان الكبير
          Text(
            page['title']!,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              height: 1.2,
              letterSpacing: 0.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // النص الفرعي
          Text(
            page['subtitle']!,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white.withOpacity(0.9),
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
