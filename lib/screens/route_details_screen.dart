import 'dart:math' show sin, cos, sqrt, asin;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:clipboard/clipboard.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../models/stop.dart';
import 'enhanced_map_screen.dart';

class UltimateRouteDetailsScreen extends StatefulWidget {
  final List<Stop> stops;
  final String routeNumber;
  final String routeType;

  const UltimateRouteDetailsScreen({
    super.key,
    required this.stops,
    this.routeNumber = "غير محدد",
    this.routeType = "أتوبيس",
  });

  @override
  State<UltimateRouteDetailsScreen> createState() => _UltimateRouteDetailsScreenState();
}

class _UltimateRouteDetailsScreenState extends State<UltimateRouteDetailsScreen> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  LatLng? _userLocation;
  bool _isLoadingLocation = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _controller.forward();

    // Move location request to post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getUserLocation();
    });
  }

  Future<void> _getUserLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) await Geolocator.requestPermission();
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _userLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  double _calculateDistance(Stop a, Stop b) {
    const double earthRadius = 6371000;
    final lat1 = a.lat * 3.14159 / 180;
    final lat2 = b.lat * 3.14159 / 180;
    final dLat = (b.lat - a.lat) * 3.14159 / 180;
    final dLng = (b.lng - a.lng) * 3.14159 / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * asin(sqrt(h));
    return earthRadius * c;
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.toStringAsFixed(0)} م';
    return '${(meters / 1000).toStringAsFixed(2)} كم';
  }

  void _shareRoute() {
    final stopsText = widget.stops.asMap().entries.map((e) {
      final i = e.key + 1;
      final stop = e.value;
      return '$i. ${stop.name}';
    }).join('\n');

  SharePlus.instance.share(ShareParams(text: '''
خط ${widget.routeNumber} - ${widget.routeType}

المحطات:
$stopsText

أنا بستخدم دليل حافلات إنجاز — أقوى تطبيق مواصلات في مصر!
حمّله الآن: https://busguide.com
  '''));
  }

  void _openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _copyCoordinates(double lat, double lng) {
    FlutterClipboard.copy('$lat, $lng');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الإحداثيات'), backgroundColor: Colors.green),
    );
  }

  void _showFullMap() {
    if (widget.stops.length < 2) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnhancedMapScreen(
          startPoint: LatLng(widget.stops.first.lat, widget.stops.first.lng),
          endPoint: LatLng(widget.stops.last.lat, widget.stops.last.lng),
          startTitle: widget.stops.first.name,
          endTitle: widget.stops.last.name,
          allStops: widget.stops,
        ),
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

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Image.asset('assets/images/play_store_512.png', width: 32, height: 32, errorBuilder: (context, error, stackTrace) => Icon(Icons.directions_bus, color: Colors.white, size: 32)),
                  const SizedBox(width: 8),
                  Image.asset('assets/palestine.png', width: 32, height: 32, errorBuilder: (context, error, stackTrace) => Icon(Icons.flag, color: Colors.green, size: 32)),
                  const SizedBox(width: 8),
                  Text('خط ${widget.routeNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                        colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.directions_bus, color: Colors.white, size: 32),
                              const SizedBox(width: 12),
                              Text(
                                widget.routeType,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${widget.stops.length} محطة • من ${widget.stops.first.name} إلى ${widget.stops.last.name}',
                            style: TextStyle(color: Colors.white70, fontSize: 14),
                            textAlign: TextAlign.center,
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
                onPressed: _shareRoute,
                tooltip: 'مشاركة المسار',
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _infoChip('إجمالي المسافة', _formatDistance(_calculateDistance(widget.stops.first, widget.stops.last))),
                  const SizedBox(width: 12),
                  _infoChip('عدد المحطات', '${widget.stops.length}'),
                  const Spacer(),
                  if (_isLoadingLocation)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else if (_userLocation != null)
                    Text('أنت قريب من المسار', style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final stop = widget.stops[index];
                final isFirst = index == 0;
                final isLast = index == widget.stops.length - 1;
                final prevStop = index > 0 ? widget.stops[index - 1] : null;
                final distance = prevStop != null ? _calculateDistance(prevStop, stop) : 0.0;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  elevation: 6,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 28,
                      backgroundColor: isFirst ? Colors.green : isLast ? Colors.red : Colors.blue,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    title: Text(
                      stop.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (prevStop != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.arrow_downward, size: 16, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text('من ${prevStop.name}', style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ),
                        if (prevStop != null)
                          Text('المسافة: ${_formatDistance(distance)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        Text('الإحداثيات: ${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}'),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.map, color: Colors.blue),
                          onPressed: () => _openMap(stop.lat, stop.lng),
                          tooltip: 'فتح في الخريطة',
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, color: Colors.green),
                          onPressed: () => _copyCoordinates(stop.lat, stop.lng),
                          tooltip: 'نسخ الإحداثيات',
                        ),
                      ],
                    ),
                    onTap: () => _showStopDialog(context, stop, index),
                  ),
                );
              },
              childCount: widget.stops.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: _showFullMap,
        tooltip: 'عرض المسار كامل على الخريطة',
        child: const Icon(Icons.map, color: Colors.white),
      ),
    );
  }

  Widget _infoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showStopDialog(BuildContext context, Stop stop, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            CircleAvatar(backgroundColor: Colors.blue, child: Text('${index + 1}')),
            const SizedBox(width: 12),
            Expanded(child: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الإحداثيات: ${stop.lat.toStringAsFixed(6)}, ${stop.lng.toStringAsFixed(6)}'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _openMap(stop.lat, stop.lng);
              },
              icon: const Icon(Icons.map),
              label: const Text('فتح في الخريطة'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}