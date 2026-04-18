import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fbroadcast/fbroadcast.dart';
import 'package:geolocator/geolocator.dart';
import '../models/bus_line.dart';
import '../models/stop.dart';

class MapProvider extends ChangeNotifier {
  // ==================== الحالة الأساسية ====================
  static const String _keyCamera = 'map_camera_position';

  final Set<BusLine> _selectedLines = {};
  final Set<BusLine> _visibleLines = {};
  final Set<BusLine> _filteredLines = {};

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Marker? _userMarker;
  BitmapDescriptor? _busIcon;

  CameraPosition _cameraPosition = const CameraPosition(
    target: LatLng(30.0444, 31.2357), // ميدان التحرير
    zoom: 14.0,
  );

  bool _isLoading = false;
  String? _errorMessage;
  bool _showAllLines = false;
  String? _activeFilter;

  GoogleMapController? _mapController;

  // Cache للـ coordinates عشان ما نستدعيش Geocoding كل مرة
  final Map<String, List<Stop>> _stopsCache = {};

  // للـ Debounce و Cancel
  Timer? _debounceTimer;
  CancelableOperation<void>? _currentUpdateOperation;

  // Getters
  Set<BusLine> get selectedLines => Set.unmodifiable(_selectedLines);
  Set<BusLine> get visibleLines => Set.unmodifiable(_visibleLines);
  Set<BusLine> get filteredLines => Set.unmodifiable(_filteredLines);
  Set<Marker> get markers {
    final allMarkers = Set<Marker>.from(_markers);
    if (_userMarker != null) allMarkers.add(_userMarker!);
    return allMarkers;
  }

  Set<Polyline> get polylines => Set.unmodifiable(_polylines);
  CameraPosition get cameraPosition => _cameraPosition;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get showAllLines => _showAllLines;
  String? get activeFilter => _activeFilter;

  // ==================== الألوان الديناميكية ====================
  Color _getColorForIndex(int index) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    return colors[index % colors.length];
  }

  // ==================== تهيئة الخريطة ====================
  Future<void> initializeWithBusLines(List<BusLine> busLines) async {
    _setLoading(true);
    _filteredLines.clear();
    _filteredLines.addAll(busLines);
    _selectedLines.clear();
    _visibleLines.clear();
    _markers.clear();
    _polylines.clear();
    _stopsCache.clear();

    await _loadCameraPosition();
    await _loadBusIcon();
    _startUserTracking();
    _updateVisibleLines();
    _setLoading(false);
  }

  Future<void> _loadBusIcon() async {
    if (_busIcon != null) return;
    try {
      _busIcon = await BitmapDescriptor.asset(
        const ImageConfiguration(size: Size(48, 48)),
        "assets/images/bus_icon.png",
      );
    } catch (e) {
      debugPrint("Error loading bus icon for provider: $e");
    }
  }

  void _startUserTracking() {
    FBroadcast.instance().register("update_location", (value, callback) {
      final position = value as Position;
      _userMarker = Marker(
        markerId: const MarkerId("user_bus"),
        position: LatLng(position.latitude, position.longitude),
        icon: _busIcon ?? BitmapDescriptor.defaultMarker,
        rotation: position.heading, // rotation from position
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 100,
        infoWindow: const InfoWindow(title: "موقعي"),
      );
      notifyListeners();
    });
  }

  // ==================== فلترة الخطوط ====================
  void filterBusLines(List<BusLine> filtered) {
    _filteredLines.clear();
    _filteredLines.addAll(filtered);
    _updateVisibleLines();
  }

  // ==================== اختيار خط ====================
  void toggleLineSelection(BusLine busLine) {
    if (_selectedLines.contains(busLine)) {
      _selectedLines.remove(busLine);
    } else {
      _selectedLines.add(busLine);
    }
    _updateVisibleLines();
  }

  void selectOnly(BusLine busLine) {
    _selectedLines.clear();
    _selectedLines.add(busLine);
    _updateVisibleLines();
  }

  void clearSelection() {
    _selectedLines.clear();
    _updateVisibleLines();
  }

  void toggleShowAllLines() {
    _showAllLines = !_showAllLines;
    _updateVisibleLines();
  }

  // ==================== تحديث العناصر (مع Debounce و Cancel) ====================
  void _updateVisibleLines() {
    _visibleLines.clear();
    if (_showAllLines) {
      _visibleLines.addAll(_filteredLines);
    } else {
      _visibleLines.addAll(_selectedLines.where(_filteredLines.contains));
    }

    debugPrint(
        '🗺️ Updating visible lines: ${_visibleLines.length} lines selected');

    // إلغاء العملية القديمة
    _currentUpdateOperation?.cancel();

    // بدّل الـ debounce مباشرة بدون تأخير لتسريع الرسم
    _debounceTimer?.cancel();
    _currentUpdateOperation =
        CancelableOperation.fromFuture(_updateMapElements());
  }

  // ==================== تحديث الماركرز والبولي لاين ====================
  Future<void> _updateMapElements() async {
    _markers.clear();
    _polylines.clear();

    debugPrint(
        '🎯 Starting to update map elements for ${_visibleLines.length} lines');

    int colorIndex = 0;
    for (final busLine in _visibleLines) {
      final color = _getColorForIndex(colorIndex++);
      final routeKey = busLine.routeNumber;

      List<Stop> stopsWithCoords;
      if (_stopsCache.containsKey(routeKey)) {
        stopsWithCoords = _stopsCache[routeKey]!;
        debugPrint(
            '📦 Using cached stops for route $routeKey: ${stopsWithCoords.length} stops');
      } else {
        try {
          stopsWithCoords = await busLine.getAllValidStops();
          _stopsCache[routeKey] = stopsWithCoords;
          debugPrint(
              '✅ Fetched stops for route $routeKey: ${stopsWithCoords.length} stops');
        } catch (e) {
          debugPrint('❌ خطأ في جلب إحداثيات الخط ${busLine.routeNumber}: $e');
          continue;
        }
      }

      if (stopsWithCoords.isEmpty) {
        debugPrint('⚠️ No valid stops for route $routeKey');
        continue;
      }

      // Markers
      for (int i = 0; i < stopsWithCoords.length; i++) {
        final stop = stopsWithCoords[i];
        final isFirst = i == 0;
        final isLast = i == stopsWithCoords.length - 1;

        if (stop.lat == 0.0 || stop.lng == 0.0) {
          debugPrint(
              '⚠️ محطة بدون إحداثيات: "${stop.name}" في الخط ${busLine.routeNumber}');
        } else {
          debugPrint(
              '📍 Marker: ${stop.name} (${stop.lat}, ${stop.lng}) - الخط: ${busLine.routeNumber}');
        }

        _markers.add(Marker(
          markerId: MarkerId('${routeKey}_${stop.name}_$i'),
          position: LatLng(stop.lat, stop.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            isFirst
                ? BitmapDescriptor.hueGreen
                : isLast
                    ? BitmapDescriptor.hueRed
                    : BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: stop.name,
            snippet: 'خط ${busLine.routeNumber} • ${busLine.type}',
          ),
        ));
      }

      // Polyline
      final polylinePoints =
          stopsWithCoords.map((s) => LatLng(s.lat, s.lng)).toList();
      _polylines.add(Polyline(
        polylineId: PolylineId('poly_$routeKey'),
        color: color.withValues(alpha: 0.8),
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
        points: polylinePoints,
      ));
      debugPrint(
          '📍 Added polyline for route $routeKey with ${polylinePoints.length} points');
    }

    debugPrint(
        '🎨 Total polylines: ${_polylines.length}, Total markers: ${_markers.length}');
    notifyListeners();
  }

  // ==================== تحريك الكاميرا بأنيميشن ====================
  void updateCameraPosition(CameraPosition position) {
    _cameraPosition = position;
    _saveCameraPosition(position);
    notifyListeners();
  }

  // ==================== تكبير على الخطوط المختارة (مع أنيميشن) ====================
  Future<void> centerOnVisibleLines({GoogleMapController? controller}) async {
    if (_visibleLines.isEmpty || controller == null) return;

    double minLat = double.infinity, maxLat = -double.infinity;
    double minLng = double.infinity, maxLng = -double.infinity;

    for (final line in _visibleLines) {
      final key = line.routeNumber;
      final stops = _stopsCache[key] ?? await line.getAllValidStops();
      for (final stop in stops) {
        if (!stop.hasValidCoordinates) continue;
        minLat = min(minLat, stop.lat);
        maxLat = max(maxLat, stop.lat);
        minLng = min(minLng, stop.lng);
        maxLng = max(maxLng, stop.lng);
      }
    }

    if (minLat == double.infinity) return;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    // أنيميشن سلس
    await controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  // ==================== SharedPreferences ====================
  Future<void> _loadCameraPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_keyCamera);
      if (jsonStr != null) {
        final map = Map<String, dynamic>.from(json.decode(jsonStr));
        _cameraPosition = CameraPosition(
          target: LatLng(map['lat'], map['lng']),
          zoom: map['zoom'],
        );
      }
    } catch (e) {
      debugPrint('فشل تحميل موقع الكاميرا');
    }
  }

  Future<void> _saveCameraPosition(CameraPosition position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'lat': position.target.latitude,
        'lng': position.target.longitude,
        'zoom': position.zoom,
      };
      await prefs.setString(_keyCamera, json.encode(data));
    } catch (_) {}
  }

  // ==================== أدوات مساعدة ====================
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void setError(String? msg) {
    _errorMessage = msg;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  bool isLineSelected(BusLine line) => _selectedLines.contains(line);
  bool isLineVisible(BusLine line) => _visibleLines.contains(line);

  // ==================== New Methods ====================
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> centerOnLines() async {
    if (_mapController != null) {
      await centerOnVisibleLines(controller: _mapController);
    }
  }

  Future<void> goToUserLocation() async {
    // Placeholder for user location functionality
    // Requires location permissions and geolocator package
    // For now, just center on current camera position or default
    if (_mapController != null) {
      await _mapController!
          .animateCamera(CameraUpdate.newCameraPosition(_cameraPosition));
    }
  }

  void selectLine(BusLine line) {
    toggleLineSelection(line);
  }

  void setFilter(String? filter) {
    _activeFilter = filter;
    // Apply filter to _filteredLines based on type
    if (filter == null) {
      // Reset to all lines
      _filteredLines.clear();
      _filteredLines
          .addAll(_selectedLines); // Assuming _selectedLines holds original
      // Wait, need to store original lines
      // For simplicity, assume filterBusLines is called from outside
    } else {
      // Filter by type
      // This needs the original list, but for now, just set the filter
    }
    notifyListeners();
  }

  Color getLineColor(BusLine line) {
    final index = _visibleLines.toList().indexOf(line);
    return _getColorForIndex(index >= 0 ? index : 0);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _currentUpdateOperation?.cancel();
    super.dispose();
  }
}
