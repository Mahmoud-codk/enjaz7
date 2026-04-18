import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as maps;
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stop.dart';
import '../services/directions_service.dart' as directions_service;
import '../services/centralized_location_service.dart';
import '../services/crowdsourcing_service.dart';

class EnhancedMapScreen extends StatefulWidget {
  final maps.LatLng startPoint;
  final maps.LatLng endPoint;
  final String startTitle;
  final String endTitle;
  final List<Stop> allStops;
  final String? routeNumber;

  const EnhancedMapScreen({
    super.key,
    required this.startPoint,
    required this.endPoint,
    required this.startTitle,
    required this.endTitle,
    required this.allStops,
    this.routeNumber,
  });

  @override
  State<EnhancedMapScreen> createState() => _EnhancedMapScreenState();
}

class _EnhancedMapScreenState extends State<EnhancedMapScreen>
    with TickerProviderStateMixin {
  maps.GoogleMapController? _mapController;
  final Set<maps.Marker> _markers = {};
  final Set<maps.Polyline> _polylines = {};
  final Set<maps.Circle> _circles = {};

  bool _isLoading = true;
  String? _error;
  late AnimationController _busController;
  maps.BitmapDescriptor? _busIcon;
  maps.Marker? _busMarker;
  bool _isNavigating = false;
  bool _isGettingLocation = false;
  
  // Real-time tracking
  StreamSubscription<QuerySnapshot>? _liveBusSubscription;
  StreamSubscription<Position>? _myLocationSubscription;
  final Map<String, maps.Marker> _liveMarkers = {};
  maps.BitmapDescriptor? _liveBusIcon;
  final CrowdsourcingService _crowdsourcingService = CrowdsourcingService();
  final CentralizedLocationService _locationService = CentralizedLocationService();

  @override
  void initState() {
    super.initState();
    _busController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadBusIcon();
      _setupMap();
    });
  }

  @override
  void dispose() {
    _busController.dispose();
    _liveBusSubscription?.cancel();
    _myLocationSubscription?.cancel();
    _locationService.stopMonitoring();
    super.dispose();
  }

  Future<void> _loadBusIcon() async {
    _busIcon = await maps.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/bus_icon.png',
    );
    _liveBusIcon = _busIcon;
    setState(() {});
  }

  Future<void> _setupMap() async {
    setState(() => _isLoading = true);

    final List<Stop> validStops = widget.allStops
        .where((s) => s.lat != 0.0 && s.lng != 0.0)
        .toList();

    if (validStops.length < 2) {
      setState(() {
        _isLoading = false;
        _error = 'لم نتمكن من تحديد مسار كافٍ (نحتاج لمحطتين على الأقل بإحداثيات صحيحة)';
      });
      return;
    }

    for (int i = 0; i < validStops.length; i++) {
      final stop = validStops[i];
      final isStart = i == 0;
      final isEnd = i == validStops.length - 1;

      _markers.add(
        maps.Marker(
          markerId: maps.MarkerId('stop_$i'),
          position: maps.LatLng(stop.lat, stop.lng),
          infoWindow: maps.InfoWindow(
            title: stop.name,
            snippet: isStart ? 'نقطة البداية' : isEnd ? 'نقطة النهاية' : 'محطة',
          ),
          icon: maps.BitmapDescriptor.defaultMarkerWithHue(
            isStart ? maps.BitmapDescriptor.hueGreen : isEnd ? maps.BitmapDescriptor.hueRed : maps.BitmapDescriptor.hueBlue,
          ),
        ),
      );

      _circles.add(
        maps.Circle(
          circleId: maps.CircleId('radius_$i'),
          center: maps.LatLng(stop.lat, stop.lng),
          radius: 100,
          fillColor: Colors.blue.withOpacity(0.1),
          strokeColor: Colors.blue,
          strokeWidth: 1,
        ),
      );
    }

    final waypointStops = (validStops.length > 2)
        ? validStops.sublist(1, validStops.length - 1)
        : <Stop>[];

    final result = await directions_service.UltimateDirectionsService.getSmartRoute(
      origin: maps.LatLng(validStops.first.lat, validStops.first.lng),
      destination: maps.LatLng(validStops.last.lat, validStops.last.lng),
      waypoints: waypointStops.map((s) => maps.LatLng(s.lat, s.lng)).toList(),
    );

    if (result['success'] == true) {
      final points = result['points'] as List<maps.LatLng>;
      _polylines.add(
        maps.Polyline(
          polylineId: const maps.PolylineId('main_route'),
          color: Colors.blue,
          width: 6,
          points: points,
        ),
      );
    } else {
      setState(() => _error = result['error']);
      _polylines.add(
        maps.Polyline(
          polylineId: const maps.PolylineId('fallback'),
          color: Colors.blue.withOpacity(0.5),
          width: 4,
          patterns: [maps.PatternItem.dash(10), maps.PatternItem.gap(10)],
          points: validStops.map((s) => maps.LatLng(s.lat, s.lng)).toList(),
        ),
      );
    }

    setState(() => _isLoading = false);
    _fitAllStops();

    if (widget.routeNumber != null) {
      _listenToLiveBuses();
    }
  }

  void _listenToLiveBuses() {
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    _liveBusSubscription = FirebaseFirestore.instance
        .collection('bus_lines')
        .doc(widget.routeNumber)
        .collection('active_trips')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      setState(() {
        final currentTripIds = snapshot.docs.map((doc) => doc.id).toSet();
        _liveMarkers.removeWhere((id, _) => !currentTripIds.contains(id));
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final GeoPoint? location = data['current_location'];
          final Timestamp? lastUpdated = data['last_updated'];
          if (location != null && lastUpdated != null && lastUpdated.toDate().isAfter(fiveMinutesAgo)) {
            final latLng = maps.LatLng(location.latitude, location.longitude);
            _liveMarkers[doc.id] = maps.Marker(
              markerId: maps.MarkerId('live_bus_${doc.id}'),
              position: latLng,
              icon: _liveBusIcon ?? maps.BitmapDescriptor.defaultMarkerWithHue(maps.BitmapDescriptor.hueAzure),
              rotation: (data['heading'] ?? 0.0) as double,
              anchor: const Offset(0.5, 0.5),
              infoWindow: maps.InfoWindow(title: 'أتوبيس مباشر (${widget.routeNumber})', snippet: 'موقع حي عبر مستخدم آخر'),
            );
          } else {
            _liveMarkers.remove(doc.id);
          }
        }
      });
    });
  }

  void _fitAllStops() {
    final validStops = widget.allStops.where((s) => s.lat != 0.0 && s.lng != 0.0).toList();
    if (validStops.isEmpty || _mapController == null) return;

    final minLat = validStops.map((s) => s.lat).reduce(min);
    final maxLat = validStops.map((s) => s.lat).reduce(max);
    final minLng = validStops.map((s) => s.lng).reduce(min);
    final maxLng = validStops.map((s) => s.lng).reduce(max);

    final bounds = maps.LatLngBounds(
      southwest: maps.LatLng(minLat, minLng),
      northeast: maps.LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(maps.CameraUpdate.newLatLngBounds(bounds, 100));
  }

  void _startNavigation() async {
    setState(() => _isNavigating = true);
    await _locationService.startMonitoring();
    _myLocationSubscription = _locationService.positionStream.listen((position) {
      if (!mounted) return;
      final latLng = maps.LatLng(position.latitude, position.longitude);
      setState(() {
        if (_busMarker != null) _markers.remove(_busMarker);
        _busMarker = maps.Marker(
          markerId: const maps.MarkerId('moving_bus'),
          position: latLng,
          icon: _busIcon ?? maps.BitmapDescriptor.defaultMarker,
          rotation: position.heading,
          anchor: const Offset(0.5, 0.5),
          infoWindow: const maps.InfoWindow(title: 'موقعي الحالي (على الحافلة)'),
        );
        _markers.add(_busMarker!);
      });
      _mapController?.animateCamera(maps.CameraUpdate.newLatLng(latLng));
      if (widget.routeNumber != null) {
        _crowdsourcingService.updateLiveLocation(routeNumber: widget.routeNumber!, position: position);
      }
      if (widget.allStops.isNotEmpty) {
        final lastStop = widget.allStops.last;
        final dist = Geolocator.distanceBetween(position.latitude, position.longitude, lastStop.lat, lastStop.lng);
        if (dist < 100) {
          _stopNavigation();
          _showArrivalDialog();
        }
      }
    });
    _busController.forward();
  }

  void _stopNavigation() {
    _myLocationSubscription?.cancel();
    _locationService.stopMonitoring();
    if (widget.routeNumber != null) _crowdsourcingService.stopTrip(widget.routeNumber!);
    setState(() => _isNavigating = false);
  }

  void _showArrivalDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        content: lottie.Lottie.asset('assets/animations/arrival.json', width: 300, height: 300, repeat: false),
      ),
    );
    Future.delayed(const Duration(seconds: 4), () => Navigator.pop(context));
  }

  Future<void> _goToCurrentLocation() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _mapController?.animateCamera(maps.CameraUpdate.newLatLngZoom(maps.LatLng(position.latitude, position.longitude), 16));
    } finally {
      setState(() => _isGettingLocation = false);
    }
  }

  void _shareRoute() {
    final stopsText = widget.allStops.map((s) => '• ${s.name}').join('\n');
    SharePlus.instance.share(ShareParams(text: 'الحافلة وصلت!\nخط ${widget.routeNumber ?? ''}\n\nالمحطات:\n$stopsText'));
  }

  double _calculateTotalDistance() {
    final List<Stop> validStops = widget.allStops.where((s) => s.lat != 0.0 && s.lng != 0.0).toList();
    if (validStops.length < 2) return 0.0;
    double total = 0.0;
    for (int i = 0; i < validStops.length - 1; i++) {
        total += _haversine(validStops[i].lat, validStops[i].lng, validStops[i+1].lat, validStops[i+1].lng);
    }
    return total;
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final distance = _calculateTotalDistance();
    final duration = distance / 25.0 * 60; // Minutes at 25km/h

    return Scaffold(
      body: Stack(
        children: [
          maps.GoogleMap(
            initialCameraPosition: maps.CameraPosition(target: widget.startPoint, zoom: 12),
            onMapCreated: (c) {
              _mapController = c;
              Future.delayed(const Duration(milliseconds: 250), () => _fitAllStops());
            },
            markers: {..._markers, ..._liveMarkers.values},
            polylines: _polylines,
            circles: _circles,
            myLocationEnabled: false, // Disable blue dot to show only the bus icon
            myLocationButtonEnabled: false,
            trafficEnabled: true,
          ),
          if (_isLoading) Positioned.fill(child: Container(color: Colors.black54, child: Center(child: lottie.Lottie.asset('assets/animations/bus_loading.json', width: 200)))),
          if (_error != null) Positioned(bottom: 100, left: 16, right: 16, child: Card(color: Colors.red, child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center)))),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16, right: 16,
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(widget.routeNumber ?? 'خط الحافلة', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                        children: [
                            Expanded(child: _infoChip(Icons.location_on, widget.startTitle, Colors.green)),
                            const Icon(Icons.arrow_forward, color: Colors.grey),
                            Expanded(child: _infoChip(Icons.flag, widget.endTitle, Colors.red)),
                        ]
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _stat('المسافة', '${distance.toStringAsFixed(1)} كم'),
                        _stat('الوقت', '${duration.toInt()} د'),
                        _stat('السعر', '0.0 ج.م'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 20, left: 16, right: 16,
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _isNavigating ? null : _startNavigation, icon: const Icon(Icons.navigation), label: Text(_isNavigating ? 'جاري التنقل...' : 'ابدأ الرحلة'), style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))))),
                const SizedBox(width: 12),
                FloatingActionButton(onPressed: _goToCurrentLocation, child: const Icon(Icons.my_location)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Row(children: [Icon(icon, color: color, size: 20), const SizedBox(width: 8), Flexible(child: Text(text, style: TextStyle(color: color), overflow: TextOverflow.ellipsis))]);
  }

  Widget _stat(String label, String value) {
    return Column(children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]);
  }
}
