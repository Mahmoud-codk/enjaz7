import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/search_panel.dart';
import '../widgets/bus_list.dart';
import '../models/bus_line.dart';
import '../data/bus_data.dart';
import '../widgets/app_bottom_navigation.dart';
import '../models/stop.dart';
import '../services/location_notification_service.dart';
import '../services/cache_service.dart';
import '../services/driver_location_service.dart';
import '../utils/responsive.dart';
import '../widgets/notification_icon.dart';
import 'notifications_screen.dart';
import 'dart:async';
import 'package:fbroadcast/fbroadcast.dart';
// chat screen removed from HomeScreen actions

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final List<Stop> demoStops = [
    Stop(name: 'التجمع الثالث', lat: 30.0500, lng: 31.4000),
    Stop(name: 'ميدان أرابيلا', lat: 30.0600, lng: 31.4100),
  ];

  late List<BusLine> filteredBusLines;
  bool isSearching = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  late gmaps.GoogleMapController _mapController;
  final Set<gmaps.Marker> _markers = {};
  final Set<gmaps.Polyline> _polylines = {};
  bool showMap = false;
  gmaps.LatLng? _currentUserLocation;
  bool _isMapLoading = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isMounted = true;

  UltimateLocationNotificationService? _locationService;

  int _currentIndex = 0;

  String? _nearestStopName;
  double? _nearestStopDistance;
  double _nearestStopSpeed = 0.0;
  String _nearestStopEta = 'غير متاح';
  String? _nextStopName;
  double _routeProgress = 0.0; // نسبة التقدّم إلى المحطة الحالية
  bool _isServiceActive = false;
  bool _voiceAlertsEnabled = true;
  final Set<String> _visitedStops = {};
  Timer? _nearestStopTimer;

  // Driver location
  final DriverLocationService _driverLocationService = DriverLocationService();
  gmaps.LatLng? _driverLocation;
  String? _driverEta;
  gmaps.BitmapDescriptor? _busIcon;
  gmaps.Marker? _userMarker;
  double _userHeading = 0.0;

  @override
  void initState() {
    super.initState();
    // initialize collection early to avoid late errors in build
    filteredBusLines = [];
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();

    // Move heavy initialization to post-frame callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAssets();
      _initializeApp();
    });

    // Listen to location updates
    FBroadcast.instance().register("update_location", (value, callback) {
      if (_isMounted) {
        final position = value as Position;
        setState(() {
          _currentUserLocation =
              gmaps.LatLng(position.latitude, position.longitude);
          _userHeading = position.heading;
          _updateUserMarker();
        });
      }
    });
  }

  Future<void> _loadAssets() async {
    _busIcon = await gmaps.BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/images/bus_icon.png',
    );
  }

  void _updateUserMarker() {
    if (_currentUserLocation != null) {
      _markers.removeWhere((m) => m.markerId.value == 'user_bus');
      _userMarker = gmaps.Marker(
        markerId: const gmaps.MarkerId('user_bus'),
        position: _currentUserLocation!,
        icon: _busIcon ?? gmaps.BitmapDescriptor.defaultMarker,
        rotation: _userHeading,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 100,
      );
      _markers.add(_userMarker!);
    }
  }

  Future<void> _initializeApp() async {
    try {
      // Add timeout to prevent long delays
      await Future.any([
        Future.wait([_loadBusLines(), _setupLocationService()]),
        Future.delayed(const Duration(seconds: 5)), // Timeout after 5 seconds
      ]);
    } catch (e, st) {
      debugPrint('Error initializing HomeScreen: $e\n$st');
      if (_isMounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'فشل في تحميل البيانات. جرب إعادة المحاولة.';
        });
      }
    } finally {
      if (_isMounted) {
        setState(() => _isLoading = false);
      } else {
        debugPrint('HomeScreen unmounted before initialization completed');
      }
    }
  }

  Future<void> _loadBusLines() async {
    try {
      final cached = await UltimateCacheService.getCachedBusLines();
      if (cached != null && cached.isNotEmpty) {
        filteredBusLines = cached;
      } else {
        final lines = busLinesData.map((e) => BusLine.fromMap(e)).toList();
        await UltimateCacheService.cacheBusLines(lines);
        filteredBusLines = lines;
      }
    } catch (e) {
      debugPrint('Error loading bus lines: $e');
      // Load default data if cache fails
      filteredBusLines = busLinesData.map((e) => BusLine.fromMap(e)).toList();
    }
  }

  Future<void> _setupLocationService() async {
    try {
      final locale = Localizations.localeOf(context);
      for (var stop in demoStops) {
        _markers.add(
          gmaps.Marker(
            markerId: gmaps.MarkerId(stop.name),
            position: gmaps.LatLng(stop.latitude, stop.longitude),
            infoWindow: gmaps.InfoWindow(title: stop.getLocalizedName(locale)),
            icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
              gmaps.BitmapDescriptor.hueBlue,
            ), // Changed to blue
          ),
        );
      }

      _locationService = UltimateLocationNotificationService(stops: demoStops);
      await _locationService?.initialize();

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      // Get current location
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      _currentUserLocation = gmaps.LatLng(
        position.latitude,
        position.longitude,
      );

      // Add current location marker
      _markers.add(
        gmaps.Marker(
          markerId: const gmaps.MarkerId('current_location'),
          position: _currentUserLocation!,
          infoWindow: const gmaps.InfoWindow(title: 'موقعك الحالي'),
          icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
            gmaps.BitmapDescriptor.hueGreen,
          ),
        ),
      );

      // Add route polyline between stops
      _addRoutePolyline();

      await _locationService?.startMonitoring();
      _startNearestStopWatcher();

      if (mounted) {
        setState(() {
          _isServiceActive = true;
        });
      }

      final prefs = await SharedPreferences.getInstance();
      _voiceAlertsEnabled = prefs.getBool('voice_alerts_enabled') ?? true;

      // Start listening to driver location
      _driverLocationService.listenToDriverLocation('driver_1', (locationData) {
        if (locationData != null && mounted) {
          setState(() {
            _driverLocation = gmaps.LatLng(
              locationData['latitude'] as double,
              locationData['longitude'] as double,
            );
            _driverEta = locationData['eta_to_nearest'] as String?;
          });
          // Update driver marker
          _updateDriverMarker();
        }
      });

      // Note: UltimateLocationNotificationService doesn't have locationStream, so we can't listen to it directly
    } catch (e) {
      debugPrint('Error setting up location service: $e');
      // Continue without location service
    }
  }

  void updateSearchResults(List<BusLine> results, bool searching) {
    setState(() {
      filteredBusLines = results;
      isSearching = searching;
    });
  }

  void _onMapCreated(gmaps.GoogleMapController controller) {
    _mapController = controller;
    if (_currentUserLocation != null) {
      _mapController.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(_currentUserLocation!, 16),
      );
    }
    setState(() => _isMapLoading = false);
  }

  void _goToCurrentLocation() async {
    if (_currentUserLocation != null) {
      _mapController.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(_currentUserLocation!, 17),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد موقعك الحالي'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _toggleMonitoring(bool value) async {
    if (value) {
      await _locationService?.startMonitoring();
    } else {
      await _locationService?.stopMonitoring();
    }
    if (!mounted) return;
    setState(() {
      _isServiceActive = value;
    });
  }

  Future<void> _toggleVoiceAlerts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_alerts_enabled', value);
    if (!mounted) return;
    setState(() {
      _voiceAlertsEnabled = value;
    });
  }

  void _startNearestStopWatcher() {
    _nearestStopTimer?.cancel();
    _nearestStopTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final stopName = prefs.getString('nearest_stop_name');
      final distance = prefs.getDouble('nearest_stop_distance');
      final speed = prefs.getDouble('nearest_stop_speed_mps') ?? 0.0;
      final etaText = prefs.getString('nearest_stop_eta_text') ?? 'غير متاح';
      final nextStopName = prefs.getString('next_stop_name');

      if (!mounted) return;
      final double routeProgress = (distance != null && distance <= 200)
          ? (1.0 - (distance / 200)).clamp(0.0, 1.0)
          : 0.0;

      if (_nearestStopName != null && distance != null && distance <= 50) {
        _visitedStops.add(_nearestStopName!);
      }

      setState(() {
        _nearestStopName = stopName;
        _nearestStopDistance = distance;
        _nearestStopSpeed = speed;
        _nearestStopEta = etaText;
        _nextStopName = nextStopName;
        _routeProgress = routeProgress;
      });

      _updateRoutePolyline();
    });
  }


  void _addRoutePolyline() {
    final polylinePoints = demoStops
        .map((stop) => gmaps.LatLng(stop.latitude, stop.longitude))
        .toList();
    _polylines.add(
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route'),
        points: polylinePoints,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  void _updateRoutePolyline() {
    if (_driverLocation == null && _currentUserLocation == null) return;

    double startLat =
        _driverLocation?.latitude ?? _currentUserLocation!.latitude;
    double startLng =
        _driverLocation?.longitude ?? _currentUserLocation!.longitude;

    List<Stop> upcomingStops =
        demoStops.where((stop) => !_visitedStops.contains(stop.name)).toList();

    if (upcomingStops.isEmpty) {
      upcomingStops = List<Stop>.from(demoStops);
    }

    upcomingStops.sort((a, b) {
      double da = Geolocator.distanceBetween(
          startLat, startLng, a.latitude, a.longitude);
      double db = Geolocator.distanceBetween(
          startLat, startLng, b.latitude, b.longitude);
      return da.compareTo(db);
    });

    List<gmaps.LatLng> points = [gmaps.LatLng(startLat, startLng)];
    points.addAll(
        upcomingStops.map((s) => gmaps.LatLng(s.latitude, s.longitude)));

    _polylines.removeWhere(
        (polyline) => polyline.polylineId.value == 'route_dynamic');
    _polylines.add(
      gmaps.Polyline(
        polylineId: const gmaps.PolylineId('route_dynamic'),
        points: points,
        color: Colors.deepOrange,
        width: 4,
        patterns: [
          gmaps.PatternItem.dash(10),
          gmaps.PatternItem.gap(6),
        ],
      ),
    );

    setState(() {});
  }

  void _updateDriverMarker() {
    if (_driverLocation == null) return;

    _markers
        .removeWhere((marker) => marker.markerId.value == 'driver_location');
    _markers.add(
      gmaps.Marker(
        markerId: const gmaps.MarkerId('driver_location'),
        position: _driverLocation!,
        infoWindow: gmaps.InfoWindow(
          title: 'موقع السائق',
          snippet: _driverEta != null ? 'ETA: $_driverEta' : null,
        ),
        icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
          gmaps.BitmapDescriptor.hueRed,
        ),
      ),
    );

    if (showMap) {
      _mapController.animateCamera(
        gmaps.CameraUpdate.newLatLng(_driverLocation!),
      );
    }
  }

  @override
  void dispose() {
    _isMounted = false;
    FBroadcast.instance().unregister(this);
    _animationController.dispose();
    _nearestStopTimer?.cancel();
    _locationService?.stopMonitoring();
    _driverLocationService.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/bus_loading.json',
                    width: Responsive.w(context, 200),
                  ),
                  SizedBox(height: Responsive.h(context, 32)),
                  Text(
                    isEn ? 'Loading Bus Guide...' : 'جاري تحميل دليل الحافلات...',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.sp(context, 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_hasError) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue[700]!, Colors.blue[900]!],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: Responsive.w(context, 100),
                    color: Colors.white,
                  ),
                  SizedBox(height: Responsive.h(context, 32)),
                  Text(
                    _errorMessage,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.sp(context, 18)),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: Responsive.h(context, 32)),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _hasError = false;
                        _errorMessage = '';
                      });
                      _initializeApp();
                    },
                    child: Text(isEn ? 'Retry' : 'إعادة المحاولة'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar:
          false, // Changed to false to prevent layout issues
      appBar: AppBar(
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        title: FadeTransition(
          opacity: _fadeAnimation,
          child: Row(
            // allow the text to shrink/ellipsis instead of overflowing
            children: [
              Hero(
                tag: 'logo',
                child: Image.asset(
                  'assets/images/play_store_512.png',
                  height: Responsive.h(context, 40),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  isEn ? 'Enjaz Bus Guide' : 'دليل حافلات إنجاز',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          NotificationIcon(
            onTap: () {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => const NotificationsScreen(),
                ),
              )
                  .then((_) {
                // Refresh badge after returning from notifications
                setState(() {});
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        // Added SafeArea to handle notches and keyboard
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [Colors.grey[900]!, Colors.black]
                      : [Colors.blue[50]!, Colors.white],
                ),
              ),
              child: showMap
                  ? Stack(
                      children: [
                        gmaps.GoogleMap(
                          onMapCreated: _onMapCreated,
                          initialCameraPosition: gmaps.CameraPosition(
                            target: _currentUserLocation ??
                                const gmaps.LatLng(30.0444, 31.2357),
                            zoom: 13,
                          ),
                          markers: _markers,
                          polylines: _polylines,
                          myLocationEnabled:
                              false, // Disable blue dot, use custom bus marker instead
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                          trafficEnabled: true,
                        ),
                        if (_isMapLoading)
                          const Center(child: CircularProgressIndicator()),
                        Positioned(
                          top: Responsive.h(context, 100),
                          left: Responsive.w(context, 16),
                          right: Responsive.w(context, 16),
                          child: Card(
                            child: ListTile(
                              leading: const Icon(
                                Icons.location_on,
                                color: Colors.blue,
                              ),
                              title: Text(
                                _currentUserLocation != null
                                    ? (isEn ? 'You are in: Enjaz' : 'أنت في: إنجاز')
                                    : (isEn ? 'Determining location...' : 'جاري تحديد موقعك...'),
                              ),
                              subtitle: Text(
                                isEn ? 'Nearby lines will appear soon' : 'الخطوط القريبة منك ستظهر قريبًا',
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: Responsive.h(context, 20),
                          right: Responsive.w(context, 16),
                          child: FloatingActionButton(
                            heroTag: 'current_location',
                            onPressed: _goToCurrentLocation,
                            backgroundColor: Colors.blue,
                            tooltip: 'موقعي الحالي',
                            child: const Icon(Icons.my_location),
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      // Made scrollable to handle keyboard
                      child: Column(
                        children: [
                          SearchPanel(
                            onSearch: updateSearchResults,
                            busLinesData: busLinesData
                                .map((e) => Map<String, String>.from(e))
                                .toList(),
                          ),
                          Container(
                            margin: const EdgeInsets.only(top: 16),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(30),
                              ),
                            ),
                            child: UltimateBusList(busLines: filteredBusLines),
                          ),
                        ],
                      ),
                    ),
            ),
            if (_nearestStopName != null)
              Positioned(
                top: Responsive.h(context, 10),
                left: Responsive.w(context, 12),
                right: Responsive.w(context, 12),
                child: Card(
                  color: Colors.blue[700]!.withValues(alpha: 0.95),
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.access_time, color: Colors.white),
                                SizedBox(width: 8),
                                Text(
                                  'حالة المراقبة',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  _isServiceActive ? 'مفعل' : 'متوقف',
                                  style: const TextStyle(color: Colors.white70),
                                ),
                                Switch(
                                  value: _isServiceActive,
                                  activeThumbColor: Colors.greenAccent,
                                  onChanged: _toggleMonitoring,
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'تنبيهات صوتية',
                              style: TextStyle(color: Colors.white70),
                            ),
                            Switch(
                              value: _voiceAlertsEnabled,
                              activeThumbColor: Colors.orangeAccent,
                              onChanged: _toggleVoiceAlerts,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'أقرب محطة: $_nearestStopName',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'المسافة: ${_nearestStopDistance?.toStringAsFixed(0) ?? '-'} م • ETA: $_nearestStopEta',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        Text(
                          'السرعة: ${_nearestStopSpeed.toStringAsFixed(1)} م/ث • حالة: ${_nearestStopSpeed > 0.6 ? 'سائر' : 'موقف'}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (_nextStopName != null)
                          Text(
                            'المحطة القادمة: $_nextStopName',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.white70),
                          ),
                        const SizedBox(height: 6),
                        LinearProgressIndicator(
                          value: _routeProgress,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.lightGreenAccent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEn ? 'Route Progress: ${(100 * _routeProgress).toStringAsFixed(0)}%' : 'تقدّم المسار: ${(100 * _routeProgress).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_driverLocation != null)
              Positioned(
                top: Responsive.h(context, 170), // Below the nearest stop card
                left: Responsive.w(context, 12),
                right: Responsive.w(context, 12),
                child: Card(
                  color: Colors.red.withValues(alpha: 0.95),
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    dense: true,
                    leading:
                        const Icon(Icons.directions_bus, color: Colors.white),
                    title: const Text('موقع السائق',
                        style: TextStyle(color: Colors.white)),
                    subtitle: Text(
                      'الإحداثيات: ${_driverLocation!.latitude.toStringAsFixed(4)}, ${_driverLocation!.longitude.toStringAsFixed(4)} • ETA: ${_driverEta ?? 'غير متاح'}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.my_location, color: Colors.white),
                      onPressed: () {
                        _mapController.animateCamera(
                          gmaps.CameraUpdate.newLatLngZoom(
                              _driverLocation!, 16),
                        );
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),

      bottomNavigationBar: AppBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) Navigator.pushNamed(context, '/favorites');
          if (index == 2) Navigator.pushNamed(context, '/history');
          if (index == 3) Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }
}
