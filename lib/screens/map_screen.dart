import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart' as lottie;
import 'package:geolocator/geolocator.dart';
import 'package:fbroadcast/fbroadcast.dart';

import '../../common/globs.dart';
import '../../common/location_manager.dart';
import '../../services/service_call.dart';
import '../../services/socket_manager.dart';
import '../models/stop.dart';
import '../services/directions_service.dart';

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key});

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen>
    with TickerProviderStateMixin {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();
  GoogleMapController? mapController;
  List<Stop> stops = [];
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  bool _isLoadingRoute = true;
  String? _routeError;
  List<String> availableLines = [];
  String selectedLine = 'line1';
  bool _isLoadingLines = true;

  LatLng currentPosition = const LatLng(30.0444, 31.2357);
  Map<String, Marker> usersCarArr = {};
  Marker? _myLocationMarker;

  BitmapDescriptor? icon;
  late AnimationController _pulseController;

  LatLng? _busPosition;
  Map<String, Marker> _liveBusMarkers = {};
  StreamSubscription? _liveTrackingSub;
  BitmapDescriptor? _busIcon;

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat();

    getIcon();
    getBusIcon();
    LocationManager.shared.startTracking();
    currentPosition = LatLng(
        LocationManager.shared.currentPos?.latitude ?? 30.0444,
        LocationManager.shared.currentPos?.longitude ?? 31.2357);

    SocketManager.shared.init(SVKey.mainUrl);
    SocketManager.shared.on(SVKey.nvCarJoin, (data) {
      if (data[KKey.status] == "1") {
        updateOtherCarLocation(data[KKey.payload] as Map? ?? {});
      }
    });

    SocketManager.shared.on(SVKey.nvCarUpdateLocation, (data) {
      if (data[KKey.status] == "1") {
        updateOtherCarLocation(data[KKey.payload] as Map? ?? {});
      }
    });

    apiCarJoin();
    fetchAvailableLines();

    // Listen to location updates to update the custom bus marker
    FBroadcast.instance().register("update_location", (value, callback) {
      if (mounted) {
        setState(() {
          final position = value as Position;
          currentPosition = LatLng(position.latitude, position.longitude);
          
          _myLocationMarker = Marker(
            markerId: const MarkerId("my_location"),
            position: currentPosition,
            icon: _busIcon ?? BitmapDescriptor.defaultMarker,
            rotation: LocationManager.shared.carDegree,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 20,
            infoWindow: const InfoWindow(title: "موقعي (الحافلة)"),
          );
        });
      }
    });
  }

  Future<void> getIcon() async {
    icon = await BitmapDescriptor.asset(
      const ImageConfiguration(devicePixelRatio: 3.2),
      "assets/images/bus_icon.png",
    );
    setState(() {});
  }

  Future<void> getBusIcon() async {
    _busIcon = await BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/images/bus_icon.png",
    );
    setState(() {});
  }

  Future<void> fetchAvailableLines() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('bus_lines').get();
      availableLines = snapshot.docs.map((doc) => doc.id).toList();
      if (availableLines.isNotEmpty && !availableLines.contains(selectedLine)) {
        selectedLine = availableLines.first;
      }
      setState(() => _isLoadingLines = false);
      await fetchStops();
      _startLiveTracking();
    } catch (e) {
      setState(() {
        _isLoadingLines = false;
        _routeError = 'فشل تحميل الخطوط: $e';
      });
    }
  }

  Future<void> fetchStops() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bus_lines')
        .doc(selectedLine)
        .collection('stops')
        .orderBy('order')
        .get();

    stops = snapshot.docs.map((doc) => Stop.fromMap(doc.data())).toList();
    await setMarkersAndPolyline();
  }

  Future<void> setMarkersAndPolyline() async {
    markers = stops.asMap().entries.map((entry) {
      int index = entry.key;
      Stop stop = entry.value;
      return Marker(
        markerId: MarkerId('stop_$index'),
        position: LatLng(stop.lat, stop.lng),
        infoWindow: InfoWindow(
          title: stop.name,
          snippet: index == 0
              ? 'نقطة البداية'
              : index == stops.length - 1
                  ? 'نقطة النهاية'
                  : 'محطة ${index + 1}',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          index == 0
              ? BitmapDescriptor.hueGreen
              : index == stops.length - 1
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueAzure,
        ),
      );
    }).toSet();

    // Route
    if (stops.length > 1) {
      setState(() => _isLoadingRoute = true);
      final result = await UltimateDirectionsService.getSmartRoute(
        origin: LatLng(stops.first.lat, stops.first.lng),
        destination: LatLng(stops.last.lat, stops.last.lng),
        waypoints: stops
            .sublist(1, stops.length - 1)
            .map((s) => LatLng(s.lat, s.lng))
            .toList(),
      );

      polylines.clear();
      if (result['success'] == true) {
        final points = result['points'] as List<LatLng>;
        polylines.add(Polyline(
          polylineId: const PolylineId('live_route'),
          color: Colors.blue,
          width: 6,
          patterns: [PatternItem.dash(30), PatternItem.gap(10)],
          points: points,
        ));
      } else {
        polylines.add(Polyline(
          polylineId: const PolylineId('fallback'),
          color: Colors.grey,
          width: 5,
          points: stops.map((s) => LatLng(s.lat, s.lng)).toList(),
        ));
      }
      setState(() => _isLoadingRoute = false);
    }

    setState(() {});
    _fitBounds();
  }

  void _fitBounds() {
    if (stops.isEmpty || mapController == null) return;
    LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(stops.map((s) => s.lat).reduce((a, b) => a < b ? a : b),
          stops.map((s) => s.lng).reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(stops.map((s) => s.lat).reduce((a, b) => a > b ? a : b),
          stops.map((s) => s.lng).reduce((a, b) => a > b ? a : b)),
    );
    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  void _startLiveTracking() {
    _liveTrackingSub?.cancel();
    _liveBusMarkers.clear();

    _liveTrackingSub = FirebaseFirestore.instance
        .collection('bus_lines')
        .doc(selectedLine)
        .collection('active_trips')
        .snapshots()
        .listen((querySnapshot) {
      bool needUpdate = false;
      final now = DateTime.now();

      final currentTripIds = <String>{};

      for (var doc in querySnapshot.docs) {
        if (doc.exists && doc.data()['current_location'] != null) {
          final data = doc.data();
          final lastUpdated = data['last_updated'] as Timestamp?;

          if (lastUpdated != null) {
            final age = now.difference(lastUpdated.toDate());
            if (age.inMinutes > 15) {
              continue; // Skip old/dead trips
            }
          }

          final geo = data['current_location'] as GeoPoint;
          final newPos = LatLng(geo.latitude, geo.longitude);
          final speed = data['speed'] ?? 0.0;
          final heading = data['heading'] ?? 0.0;
          final tripId = doc.id;
          currentTripIds.add(tripId);

          _liveBusMarkers[tripId] = Marker(
            markerId: MarkerId('live_bus_$tripId'),
            position: newPos,
            icon: _busIcon ?? BitmapDescriptor.defaultMarker,
            rotation: double.tryParse(heading.toString()) ?? 0.0,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 10,
            infoWindow: InfoWindow(
              title: 'حافلة حية',
              snippet:
                  'السرعة: ${num.tryParse(speed.toString())?.toStringAsFixed(1) ?? '0'} كم/س',
            ),
          );

          if (_busPosition == null || currentTripIds.length == 1) {
            _busPosition = newPos;
          }
          needUpdate = true;
        }
      }

      // إزالة الرحلات المنتهية أو غير النشطة
      _liveBusMarkers.removeWhere((tripId, marker) {
        final remove = !currentTripIds.contains(tripId);
        if (remove) needUpdate = true;
        return remove;
      });

      if (needUpdate && mounted) {
        setState(() {});
      }
    });
  }

  void _onLineChanged(String? newLine) {
    if (newLine != null && newLine != selectedLine) {
      setState(() {
        selectedLine = newLine;
        stops = [];
        markers.clear();
        polylines.clear();
        _liveBusMarkers.clear();
        _isLoadingRoute = true;
      });
      fetchStops();
      _startLiveTracking();
    }
  }

  Future<void> _goToTheLake() async {
    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
        CameraPosition(target: currentPosition, zoom: 17)));
  }

  void updateOtherCarLocation(Map obj) {
    final uuid = obj["uuid"]?.toString() ?? '';
    usersCarArr[uuid] = Marker(
        markerId: MarkerId(uuid),
        position: LatLng(
            double.tryParse(obj["lat"]?.toString() ?? '0.0') ?? 0.0,
            double.tryParse(obj["long"]?.toString() ?? '0.0') ?? 0.0),
        icon: icon ?? BitmapDescriptor.defaultMarker,
        rotation: double.tryParse(obj["degree"]?.toString() ?? '0.0') ?? 0.0,
        anchor: const Offset(0.5, 0.5));

    if (mounted) {
      setState(() {});
    }
  }

  void apiCarJoin() {
    ServiceCall.post({
      "uuid": ServiceCall.userUUID,
      "lat": currentPosition.latitude.toString(),
      "long": currentPosition.longitude.toString(),
      "degree": LocationManager.shared.carDegree.toString(),
      "socket_id": SocketManager.shared.id ?? "",
    }, SVKey.svCarJoin, (responseObj) async {
      if (responseObj[KKey.status] == "1") {
        final payload =
            (responseObj[KKey.payload] as Map? ?? {}) as Map<String, dynamic>;
        payload.forEach((key, value) {
          updateOtherCarLocation((value as Map).cast<String, dynamic>());
        });
        if (mounted) {
          setState(() {});
        }
      } else {
        debugPrint(responseObj[KKey.message] as String? ?? 'فشل في العملية');
      }
    }, (error) async {
      debugPrint(error.toString());
    });
  }

  @override
  void dispose() {
    FBroadcast.instance().unregister(this);
    SocketManager.shared.disconnect();
    LocationManager.shared.stopTracking();
    _liveTrackingSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // isDark removed (unused)

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Row(
                children: [
                  Image.asset('assets/images/play_store_512.png',
                      width: 32, height: 32),
                  const SizedBox(width: 8),
                  AnimatedBuilder(
                    animation: _pulseController,
                    builder: (context, child) => Transform.scale(
                      scale: 1 + 0.1 * _pulseController.value,
                      child: const Icon(Icons.directions_bus_filled,
                          color: Colors.red),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('خريطة الحافلة الحية',
                      style: TextStyle(fontWeight: FontWeight.bold)),
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
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withValues(alpha: 0.8)
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            const Icon(Icons.live_tv, color: Colors.red),
                            const SizedBox(width: 12),
                            const Text('التتبع الحي مفعل',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            const Spacer(),
                            if (!_isLoadingLines && availableLines.isNotEmpty)
                              DropdownButton<String>(
                                value: selectedLine,
                                onChanged: _onLineChanged,
                                items: availableLines
                                    .map((line) => DropdownMenuItem(
                                          value: line,
                                          child: Text('خط $line',
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold)),
                                        ))
                                    .toList(),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverFillRemaining(
            child: Stack(
              children: [
                GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(30.0444, 31.2357),
                    zoom: 14.4746,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                    mapController = controller;
                    _fitBounds();
                  },
                  markers: {
                    ...markers,
                    if (_myLocationMarker != null) _myLocationMarker!,
                    ...usersCarArr.values.toSet(),
                    ..._liveBusMarkers.values.toSet()
                  },
                  polylines: polylines,
                  myLocationEnabled: false, // Disable blue dot
                  myLocationButtonEnabled: true,
                  trafficEnabled: true,
                ),

                // Loading
                if (_isLoadingRoute)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black54,
                      child: Center(
                        child: lottie.Lottie.asset(
                            'assets/animations/bus_loading.json',
                            width: 200),
                      ),
                    ),
                  ),

                // Error
                if (_routeError != null)
                  Positioned(
                    bottom: 100,
                    left: 16,
                    right: 16,
                    child: Card(
                      color: Colors.red.shade600,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(_routeError!,
                            style: const TextStyle(color: Colors.white),
                            textAlign: TextAlign.center),
                      ),
                    ),
                  ),

                // Live Bus Info
                if (_busPosition != null)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Card(
                      elevation: 8,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: LinearGradient(
                              colors: [Colors.green, Colors.green.shade700]),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_bus,
                                color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              'الحافلة في الطريق',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Palestine Flag
                Positioned(
                  bottom: 20,
                  right: 20,
                  child: GestureDetector(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('من النهر إلى البحر... فلسطين حرة'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    child: Image.asset('assets/palestine.png', width: 60),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToTheLake,
        label: const Text('To current location!'),
        icon: const Icon(Icons.my_location),
      ),
    );
  }
}
