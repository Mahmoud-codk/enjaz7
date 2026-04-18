import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/stop.dart';
import '../../services/centralized_location_service.dart';
import '../../services/directions_service.dart' as directions_service;

class StationMapDialog extends StatefulWidget {
  final Stop stop;

  const StationMapDialog({super.key, required this.stop});

  @override
  State<StationMapDialog> createState() => _StationMapDialogState();
}

class _StationMapDialogState extends State<StationMapDialog> {
  final Completer<GoogleMapController> _controller = Completer();
  StreamSubscription<Position>? _positionSubscription;
  Position? _currentPosition;
  double? _distance;
  String? _distanceText;
  String? _durationText;
  bool _isLoadingRoute = false;
  // ignore: unused_field
  String? _routeError;
  List<LatLng> _routePoints = [];
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  @override
  void initState() {
    super.initState();
    _loadMap();
    _listenToLocation();
  }

  Future<void> _loadMap() async {
    final GoogleMapController controller = await _controller.future;
    
    // Center on station initially
    controller.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(widget.stop.latitude, widget.stop.longitude),
      ),
    );

    if (_currentPosition != null) {
      await _fetchRoute();
    }
    updateMarkers();
    updatePolyline();
  }

  Future<void> _fetchRoute() async {
    if (_currentPosition == null) return;

    setState(() {
      _isLoadingRoute = true;
      _routeError = null;
    });

    try {
      await directions_service.UltimateDirectionsService.init();

      final result = await directions_service.UltimateDirectionsService.getSmartRoute(
        origin: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        destination: LatLng(widget.stop.latitude, widget.stop.longitude),
      );

      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          if (result['success'] == true) {
            _distanceText = result['distance'] as String?;
            _durationText = result['duration'] as String?;
            _routePoints = List<LatLng>.from(result['points'] as List);
          } else {
            _routeError = result['error'] as String?;
            _distanceText = '${_distance?.toStringAsFixed(1) ?? '0'} كم';
            _durationText = 'غير متاح';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = false;
          _routeError = 'خطأ: $e';
        });
      }
    }
  }

  void _listenToLocation() {
    _positionSubscription = CentralizedLocationService().positionStream.listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = position;
            calculateDistance();
          });
          _fetchRoute();
          updateMarkers();
          updatePolyline();
        }
      },
    );
  }

  void calculateDistance() {
    if (_currentPosition != null) {
      _distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        widget.stop.latitude,
        widget.stop.longitude,
      );
    }
  }

  void updateMarkers() {
    _markers = {
      Marker(
        markerId: const MarkerId('station'),
        position: LatLng(widget.stop.latitude, widget.stop.longitude),
        infoWindow: InfoWindow(title: widget.stop.name),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      ),
      if (_currentPosition != null)
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          infoWindow: const InfoWindow(title: 'موقعك الحالي'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
    };
  }

  void updatePolyline() {
    if (_currentPosition != null) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('user-to-station'),
          points: [
            LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            LatLng(widget.stop.latitude, widget.stop.longitude),
          ],
          color: Colors.blue,
          width: 4,
        ),
      };
    } else {
      _polylines.clear();
    }
  }

  Future<void> _openDirections() async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=${widget.stop.latitude},${widget.stop.longitude}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }

  String formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} م';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} كم';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.stop.name),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        body: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: LatLng(widget.stop.latitude, widget.stop.longitude),
                zoom: 15,
              ),
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: false, // Disable blue dot, use custom marker instead
              myLocationButtonEnabled: false,
            ),
            if (_currentPosition != null && _distance != null)
              Positioned(
                top: 80,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.straighten, color: Colors.blue, size: 24),
                      const SizedBox(width: 12),
                      Text(
                        'المسافة: ${formatDistance(_distance!)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: ElevatedButton.icon(
                onPressed: _openDirections,
                icon: const Icon(Icons.directions, color: Colors.white),
                label: const Text(
                  'فتح الاتجاهات',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
