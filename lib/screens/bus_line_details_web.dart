import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:html' as html;

import '../models/bus_line.dart';
import 'bus_line_details_screen.dart';

class BusLineDetailsWeb extends StatefulWidget {
  final String routeNumber;

  const BusLineDetailsWeb({super.key, required this.routeNumber});

  @override
  State<BusLineDetailsWeb> createState() => _BusLineDetailsWebState();
}

class _BusLineDetailsWebState extends State<BusLineDetailsWeb> {
  BusLine? _busLine;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupSEO();
    _fetchBusLine();
  }

  void _setupSEO() {
    if (!kIsWeb) return;

    final title = 'خط ${widget.routeNumber} - دليل حافلات القاهرة';
    final description = 'تفاصيل خط الحافلات رقم ${widget.routeNumber} في القاهرة الكبرى - المحطات، المسار، والخريطة';
    final url = 'https://busguide.com/line/${widget.routeNumber}';

    // تحديث العنوان
    html.document.title = title;

    // Meta Tags
    _setMeta('description', description);
    _setMeta('og:title', title);
    _setMeta('og:description', description);
    _setMeta('og:type', 'website');
    _setMeta('og:url', url);
    _setMeta('og:image', 'https://busguide.com/assets/og-image.jpg');
    _setMeta('twitter:card', 'summary_large_image');
    _setMeta('twitter:title', title);
    _setMeta('twitter:description', description);
    _setMeta('twitter:image', 'https://busguide.com/assets/og-image.jpg');

    // Canonical URL
    html.LinkElement link = html.LinkElement()
      ..rel = 'canonical'
      ..href = url;
    html.document.head!.append(link);
  }

  void _setMeta(String property, String content) {
    var meta = html.MetaElement()
      ..content = content;
    if (property.contains('og:') || property.contains('twitter:')) {
      meta.setAttribute('property', property);
    } else {
      meta.name = property;
    }
    html.document.head!.append(meta);
  }

  Future<void> _fetchBusLine() async {
    try {
      // استبدل بالـ API الحقيقي
      final response = await http.get(
        Uri.parse('https://api.busguide.com/lines/${widget.routeNumber}'),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _busLine = BusLine.fromMap(data);
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        setState(() {
          _error = 'الخط غير موجود';
          _isLoading = false;
        });
      } else {
        throw Exception('فشل في تحميل البيانات');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'لا يوجد اتصال بالإنترنت';
        _isLoading = false;
      });
    }
  }

  void _openInApp() {
    final appUrl = 'busguide://line/${widget.routeNumber}';
    final webUrl = 'https://play.google.com/store/apps/details?id=com.busguide.cairo';
    
    html.window.location.href = appUrl;
    
    // Fallback بعد 2 ثانية
    Future.delayed(const Duration(seconds: 2), () {
      html.window.location.href = webUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? _buildLoading()
          : _error != null
              ? _buildError()
              : _busLine != null
                  ? BusLineDetailsScreen(busLine: _busLine!)
                  : _buildNotFound(),
      floatingActionButton: kIsWeb
          ? FloatingActionButton.extended(
              onPressed: _openInApp,
              icon: const Icon(Icons.phone_android),
              label: const Text('افتح في التطبيق'),
              backgroundColor: Colors.green,
            )
          : null,
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.asset(
            'assets/animations/bus_loading.json',
            width: 200,
            height: 200,
          ),
          const SizedBox(height: 24),
          const Text(
            'جاري تحميل تفاصيل الخط...',
            style: TextStyle(fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 80, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => setState(() => _isLoading = true),
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => context.go('/'),
              child: const Text('العودة إلى الرئيسية'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'الخط غير موجود',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'خط ${widget.routeNumber} غير متوفر حاليًا',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('استعرض جميع الخطوط'),
            ),
          ],
        ),
      ),
    );
  }
}