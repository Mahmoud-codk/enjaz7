import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';
import '../models/bus_line.dart';
import '../providers/favorites_provider.dart';
import '../models/stop.dart';
import 'enhanced_map_screen.dart';
import '../widgets/app_drawer.dart';
import '../services/deep_link_service.dart';
import '../services/location_notification_service.dart';
import '../services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

class BusLineDetailsScreen extends StatefulWidget {
  final BusLine busLine;

  const BusLineDetailsScreen({super.key, required this.busLine});

  @override
  State<BusLineDetailsScreen> createState() => _BusLineDetailsScreenState();
}

class _BusLineDetailsScreenState extends State<BusLineDetailsScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  List<Stop> _allStops = [];
  bool _isLoadingMap = false;
  UltimateLocationNotificationService? _notificationService;
  bool _isTracking = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _loadStops();
    _checkIsTracking();
  }

  Future<void> _checkIsTracking() async {
    final prefs = await SharedPreferences.getInstance();
    final monitoringLineId = prefs.getString('monitoring_line_id');
    final isServiceRunning = await FlutterForegroundTask.isRunningService;
    if (isServiceRunning && monitoringLineId == widget.busLine.routeNumber) {
      if (mounted) {
        setState(() => _isTracking = true);
      }
    }
  }

  Future<void> _loadStops() async {
    try {
      final stops = await widget.busLine.getStopsWithCoordinates();
      setState(() => _allStops = stops);
    } catch (e) {
      // ignore
    }
  }

  Future<void> _showRouteOnMap() async {
    if (_isLoadingMap) return;
    setState(() => _isLoadingMap = true);

    try {
      if (_allStops.isEmpty) {
        _allStops = await widget.busLine.getStopsWithCoordinates();
      }

      if (_allStops.isEmpty) {
        _showSnackBar('لا توجد محطات لعرضها على الخريطة', isError: true);
        return;
      }

      final start = _allStops.first;
      final end = _allStops.last;

      if (!mounted) return;
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => EnhancedMapScreen(
            startPoint: LatLng(start.lat, start.lng),
            endPoint: LatLng(end.lat, end.lng),
            startTitle: start.name,
            endTitle: end.name,
            allStops: _allStops,
            routeNumber: widget.busLine.routeNumber,
          ),
          transitionDuration: const Duration(milliseconds: 600),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );
    } catch (e) {
      _showSnackBar('حدث خطأ: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error : Icons.check_circle,
                color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message, textDirection: TextDirection.rtl)),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _copyStation(String station) {
    Clipboard.setData(ClipboardData(text: station));
    _showSnackBar('تم نسخ "$station"', isError: false);
  }

  void _toggleTracking() async {
    if (_allStops.isEmpty) {
      _allStops = await widget.busLine.getStopsWithCoordinates();
    }
    if (_allStops.isEmpty) {
      _showSnackBar('لا توجد محطات لتتبعها', isError: true);
      return;
    }

    if (_isTracking) {
      if (_notificationService == null) {
        _notificationService = UltimateLocationNotificationService(
          stops: _allStops,
          lineId: widget.busLine.routeNumber,
        );
      }
      await _notificationService?.stopMonitoring();
      if (mounted) setState(() => _isTracking = false);
      _showSnackBar('تم إيقاف التنبيه ومشاركة الموقع');
    } else {
      // Don't show interstitial ad until the user selects a destination
      _showDestinationDialog();
    }
  }

  void _showDestinationDialog() {
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Where are you heading?' : 'إلى أي محطة تتجه؟',
            textDirection: isEn ? TextDirection.ltr : TextDirection.rtl),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _allStops.length,
            itemBuilder: (context, index) {
              final stop = _allStops[index];
              return ListTile(
                title: Text(stop.getLocalizedName(locale),
                    textDirection:
                        isEn ? TextDirection.ltr : TextDirection.rtl),
                onTap: () {
                  Navigator.pop(ctx);
                  AdService.showInterstitialAd();
                  _startTrackingForDestination(stop.name);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _startTrackingForDestination(String dest) async {
    _notificationService = UltimateLocationNotificationService(
      stops: _allStops,
      targetDestination: dest,
      lineId: widget.busLine.routeNumber,
    );
    await _notificationService!.startMonitoringForDestination(dest,
        lineId: widget.busLine.routeNumber);
    if (mounted) setState(() => _isTracking = true);
    _showSnackBar('تم تفعيل التنبيه وبث الموقع');
  }

  @override
  void dispose() {
    _animationController.dispose();
    _notificationService?.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final favoritesProvider = context.watch<FavoritesProvider>();
    final isFavorite = favoritesProvider.isFavorite(widget.busLine);
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';

    final stops = widget.busLine
        .getLocalizedStops(locale)
        .expand((s) => s.split(RegExp(r'[،,.،]+')))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final stopCount = stops.length;
    final estimatedTime =
        stopCount > 1 ? (stopCount * 2.5).toInt() : 0; // دقيقة تقريبية

    return Scaffold(
      endDrawer: const UltimateAppDrawer(),
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Hero(
                    tag: 'bus_line_logo',
                    child: Image.asset('assets/images/play_store_512.png',
                        height: 32),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEn
                        ? 'Line ${widget.busLine.routeNumber}'
                        : 'خط ${widget.busLine.routeNumber}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 70,
                    left: 20,
                    right: 20,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(Icons.directions_bus,
                                  color: Colors.white, size: 36),
                              const SizedBox(width: 12),
                              Text(
                                widget.busLine.getLocalizedType(locale),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _infoChip(
                                  icon: Icons.play_arrow,
                                  label: isEn ? 'Start' : 'البداية',
                                  value: stops.isNotEmpty
                                      ? stops.first
                                      : (isEn ? 'Unknown' : 'غير معروف'),
                                  color: Colors.green,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Icon(Icons.arrow_forward,
                                    color: Colors.white70),
                              ),
                              Expanded(
                                child: _infoChip(
                                  icon: Icons.flag,
                                  label: isEn ? 'End' : 'النهاية',
                                  value: stops.isNotEmpty
                                      ? stops.last
                                      : (isEn ? 'Unknown' : 'غير معروف'),
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  // Generate deep link for this bus line
                  final deepLink =
                      deepLinkService.generateDeepLink(widget.busLine);

                  Share.share('''
🚍 خط ${widget.busLine.routeNumber} - ${widget.busLine.type}

من: ${stops.isNotEmpty ? stops.first : 'غير معروف'}
إلى: ${stops.isNotEmpty ? stops.last : 'غير معروف'}

عدد المحطات: $stopCount
المدة المتوقعة: $estimatedTime دقيقة

👇 اضغط لرؤية التفاصيل:
$deepLink

جرب تطبيق دليل حافلات القاهرة الآن!
https://play.google.com/store/apps/details?id=com.enjaz.busguide
''');
                },
              ),
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
                onPressed: () {
                  // أعد قراءة الحالة الحالية من provider
                  final currentIsFavorite =
                      favoritesProvider.isFavorite(widget.busLine);

                  if (currentIsFavorite) {
                    favoritesProvider.removeFavorite(widget.busLine);
                    _showSnackBar('تمت الإزالة من المفضلة');
                  } else {
                    favoritesProvider.addFavorite(widget.busLine).then((_) {
                      // تأخير صغير للتأكد من تحديث الـ state
                      Future.delayed(const Duration(milliseconds: 100), () {
                        if (favoritesProvider.errorMessage != null &&
                            favoritesProvider.errorMessage!
                                .contains('الحد الأقصى')) {
                          _showSnackBar(
                            favoritesProvider.errorMessage ?? 'فشل الإضافة',
                            isError: true,
                          );
                        } else {
                          _showSnackBar('تمت الإضافة إلى المفضلة',
                              isError: false);
                        }
                      });
                    });
                  }
                },
              ),
            ],
          ),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statCard(isEn ? 'Stops' : 'المحطات', '$stopCount',
                            Icons.pin_drop),
                        _statCard(
                            isEn ? 'Duration' : 'المدة',
                            isEn ? '$estimatedTime min' : '$estimatedTime د',
                            Icons.access_time),
                        _statCard(isEn ? 'Price' : 'السعر', '0.0 EGP',
                            Icons.monetization_on),
                        _statCard(isEn ? 'Status' : 'الحالة',
                            isEn ? 'Active' : 'يعمل', Icons.check_circle,
                            color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 32),

                    Text(
                      isEn
                          ? 'All Stops ($stopCount)'
                          : 'جميع المحطات ($stopCount)',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),

                    if (stops.isEmpty)
                      const Center(
                        child: Text(
                          'لا توجد محطات مفصلة متاحة حاليًا',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      )
                    else
                      ...List.generate(stops.length, (index) {
                        final stop = stops[index];
                        final isFirst = index == 0;
                        final isLast = index == stops.length - 1;

                        return GestureDetector(
                          onLongPress: () => _copyStation(stop),
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Row(
                              children: [
                                _timelineDot(
                                    isFirst, isLast, index, stops.length),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        stop,
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: isFirst || isLast
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isFirst
                                              ? Colors.green
                                              : isLast
                                                  ? Colors.red
                                                  : null,
                                        ),
                                      ),
                                      if (isFirst || isLast)
                                        Text(
                                          isFirst
                                              ? (isEn
                                                  ? 'Start Point'
                                                  : 'نقطة البداية')
                                              : (isEn
                                                  ? 'End Point'
                                                  : 'نقطة النهاية'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.content_copy,
                                  size: 18,
                                  color: Colors.grey[500],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                    const SizedBox(height: 24),
                    // زرار عرض الخريطة والتتبع
                    const SizedBox(height: 100), // للفلوتينج
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLoadingMap ? null : _showRouteOnMap,
                  icon: _isLoadingMap
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.map, size: 24),
                  label: Text(
                    _isLoadingMap
                        ? (isEn ? 'Loading...' : 'تحميل...')
                        : (isEn ? 'Map' : 'الخريطة'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    elevation: 8,
                    shadowColor:
                        Theme.of(context).colorScheme.primary.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _toggleTracking,
                  icon: Icon(
                      _isTracking
                          ? Icons.notifications_off
                          : Icons.directions_bus,
                      size: 24),
                  label: Text(
                    _isTracking
                        ? (isEn ? 'Stop Trip' : 'إيقاف الرحلة')
                        : (isEn ? "I'm on the Bus" : 'أنا بالباص'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isTracking ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: (_isTracking ? Colors.red : Colors.green)
                        .withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon,
            color: color ?? Theme.of(context).colorScheme.primary, size: 28),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }

  Widget _timelineDot(bool isFirst, bool isLast, int index, int total) {
    final color = isFirst
        ? Colors.green
        : isLast
            ? Colors.red
            : Colors.blue;

    return Column(
      children: [
        if (!isFirst)
          Container(width: 2, height: 20, color: Colors.grey.shade400),
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
            ],
          ),
        ),
        if (!isLast)
          Container(width: 2, height: 40, color: Colors.grey.shade400),
      ],
    );
  }
}
