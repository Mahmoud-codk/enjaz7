import 'dart:math';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:lottie/lottie.dart';
import '../models/stop.dart';

class DirectionsScreen extends StatefulWidget {
  final List<Stop> stops;
  final String? routeName;

  const DirectionsScreen({
    super.key,
    required this.stops,
    this.routeName,
  });

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final SpeechToText _speechToText = SpeechToText();
  bool _isListening = false;
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.forward();
    _initSpeech();
  }

  void _initSpeech() async {
    _speechEnabled = await _speechToText.initialize();
    setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    setState(() => _isListening = true);
    await _speechToText.listen(
      onResult: (result) {
        if (result.finalResult) {
          final query = result.recognizedWords;
          showSearch(
            context: context,
            delegate: StopSearchDelegate(widget.stops, query),
          );
          setState(() => _isListening = false);
        }
      },
      localeId: 'ar_EG',
    );
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  Future<void> _openMap(double lat, double lng, {bool navigation = false}) async {
    final url = navigation
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=transit'
        : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showSnackBar('لا يمكن فتح الخريطة');
    }
  }



  void _shareStop(Stop stop, int index) {
    SharePlus.instance.share(ShareParams(text: '''
محطة: ${stop.name}
الترتيب: ${index + 1}
الإحداثيات: ${stop.latitude.toStringAsFixed(6)}, ${stop.longitude.toStringAsFixed(6)}

افتح في الخريطة:
https://www.google.com/maps/search/?api=1&query=${stop.latitude},${stop.longitude}

من تطبيق دليل حافلات القاهرة
    '''));
  }

  void _copyCoordinates(Stop stop) {
    Clipboard.setData(ClipboardData(text: '${stop.latitude}, ${stop.longitude}'));
    _showSnackBar('تم نسخ الإحداثيات');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, textDirection: TextDirection.rtl),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  double _calculateDistance(Stop a, Stop b) {
    const double earthRadius = 6371000;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLng = (b.longitude - a.longitude) * pi / 180;

    final aVal = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(aVal), sqrt(1 - aVal));
    return earthRadius * c;
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
              title: Text(
                widget.routeName != null ? 'خط ${widget.routeName}' : 'اتجاهات الرحلة',
                style: const TextStyle(fontWeight: FontWeight.bold),
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
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withValues(alpha: 0.8),
                          ],
                        ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            theme.scaffoldBackgroundColor.withValues(alpha: 0.9),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                color: _isListening ? Colors.red : null,
                onPressed: _isListening ? _stopListening : _startListening,
                tooltip: 'بحث صوتي',
              ),
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () {
                  showSearch(context: context, delegate: StopSearchDelegate(widget.stops));
                },
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Mini Map
                    if (widget.stops.length > 1)
                      Container(
                        height: 200,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: gmaps.GoogleMap(
                            initialCameraPosition: gmaps.CameraPosition(
                              target: gmaps.LatLng(
                                widget.stops[widget.stops.length ~/ 2].latitude,
                                widget.stops[widget.stops.length ~/ 2].longitude,
                              ),
                              zoom: 11,
                            ),
                            markers: widget.stops
                                .asMap()
                                .entries
                                .map((e) => gmaps.Marker(
                                      markerId: gmaps.MarkerId(e.key.toString()),
                                      position: gmaps.LatLng(e.value.latitude, e.value.longitude),
                                      infoWindow: gmaps.InfoWindow(title: e.value.name),
                                      icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                        e.key == 0
                                            ? gmaps.BitmapDescriptor.hueGreen
                                            : e.key == widget.stops.length - 1
                                                ? gmaps.BitmapDescriptor.hueRed
                                                : gmaps.BitmapDescriptor.hueBlue,
                                      ),
                                    ))
                                .toSet(),
                            polylines: {
                              gmaps.Polyline(
                                polylineId: const gmaps.PolylineId('route'),
                                points: widget.stops
                                    .map((s) => gmaps.LatLng(s.latitude, s.longitude))
                                    .toList(),
                                color: Colors.blue,
                                width: 4,
                              ),
                            },
                            liteModeEnabled: true,
                          ),
                        ),
                      ),

                    // Stats
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statChip('المحطات', '${widget.stops.length}', Icons.pin_drop),
                        _statChip('المسافة', '${(widget.stops.length * 1.2).toStringAsFixed(1)} كم', Icons.directions),
                        _statChip('الوقت', '${(widget.stops.length * 2.5).toInt()} د', Icons.access_time),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Start Navigation Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openMap(
                          widget.stops.last.latitude,
                          widget.stops.last.longitude,
                          navigation: true,
                        ),
                        icon: const Icon(Icons.navigation),
                        label: const Text('ابدأ الرحلة الآن', style: TextStyle(fontSize: 18)),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final stop = widget.stops[index];
                final isFirst = index == 0;
                final isLast = index == widget.stops.length - 1;
                final distance = index > 0
                    ? _calculateDistance(widget.stops[index - 1], stop)
                    : 0.0;

                return Dismissible(
                  key: Key(stop.name),
                  background: Container(color: Colors.red),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    _showSnackBar('تم حذف ${stop.name} مؤقتًا');
                  },
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 6,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundColor: isFirst
                            ? Colors.green
                            : isLast
                                ? Colors.red
                                : Colors.blue,
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      title: Text(
                        stop.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${stop.latitude.toStringAsFixed(5)}, ${stop.longitude.toStringAsFixed(5)}'),
                          if (index > 0)
                            Text(
                              'المسافة: ${(distance / 1000).toStringAsFixed(2)} كم',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: PopupMenuButton(
                        icon: const Icon(Icons.more_vert),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            child: const Text('فتح في الخريطة'),
                            onTap: () => _openMap(stop.latitude, stop.longitude),
                          ),
                          PopupMenuItem(
                            child: const Text('مشاركة المحطة'),
                            onTap: () => _shareStop(stop, index),
                          ),
                          PopupMenuItem(
                            child: const Text('نسخ الإحداثيات'),
                            onTap: () => _copyCoordinates(stop),
                          ),
                        ],
                      ),
                      onLongPress: () => _copyCoordinates(stop),
                      isThreeLine: true,
                    ),
                  ),
                );
              },
              childCount: widget.stops.length,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}

// تحسين البحث
class StopSearchDelegate extends SearchDelegate<Stop> {
  final List<Stop> stops;
  final String? initialQuery;

  StopSearchDelegate(this.stops, [this.initialQuery]) {
    if (initialQuery != null) query = initialQuery!;
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () => query = '',
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, Stop(name: '', lat: 0, lng: 0)),
    );
  }

  @override
  Widget buildResults(BuildContext context) => _buildSuggestions();

  @override
  Widget buildSuggestions(BuildContext context) => _buildSuggestions();

  Widget _buildSuggestions() {
    final results = stops
        .where((stop) => stop.name.toLowerCase().contains(query.toLowerCase()))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Lottie.asset('assets/animations/no_results.json', width: 200),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final stop = results[index];
        return ListTile(
          leading: const Icon(Icons.location_on, color: Colors.blue),
          title: Text(stop.name),
          subtitle: Text('${stop.latitude}, ${stop.longitude}'),
          onTap: () {
            close(context, stop);
            // يمكن فتح الخريطة مباشرة
          },
        );
      },
    );
  }
}