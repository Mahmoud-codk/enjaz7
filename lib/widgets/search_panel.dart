import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/bus_line.dart';
import '../models/stop.dart';
import '../services/location_notification_service.dart';
import '../services/ad_service.dart';
import '../services/app_state_service.dart';
import 'package:provider/provider.dart';
import '../providers/history_provider.dart';
import '../models/trip_history.dart';
import '../services/station_translation_service.dart';

class SearchPanel extends StatefulWidget {
  final Function(List<BusLine>, bool) onSearch;
  final List<Map<String, String>> busLinesData;
  // When true tests can set this to avoid initializing platform plugins.
  static bool disableNotificationsForTests = false;

  const SearchPanel({
    super.key,
    required this.onSearch,
    required this.busLinesData,
  });

  @override
  State<SearchPanel> createState() => _SearchPanelState();
}

class _SearchPanelState extends State<SearchPanel> {
  final TextEditingController startController = TextEditingController();
  final TextEditingController endController = TextEditingController();
  final TextEditingController searchController = TextEditingController();
  Timer? _debounce;
  bool _notificationsEnabled = false;
  UltimateLocationNotificationService? _notificationService;

  // Sample coordinates for common Cairo bus stops (add more as needed)
  final Map<String, Map<String, double>> _stopCoordinates = {
    'رمسيس': {'lat': 30.0626, 'lng': 31.2497},
    'محطة رمسيس': {'lat': 30.0626, 'lng': 31.2497},
    'العتبة': {'lat': 30.0480, 'lng': 31.2610},
    'ميدان العتبة': {'lat': 30.0480, 'lng': 31.2610},
    'القليوب': {'lat': 30.1667, 'lng': 31.2833},
    'كوم اشفين': {'lat': 30.1333, 'lng': 31.3167},
    'روض الفرج': {'lat': 30.1167, 'lng': 31.2667},
    'شبرا': {'lat': 30.0667, 'lng': 31.2333},
    'ميدان المؤسسة': {'lat': 30.1000, 'lng': 31.3000},
    'كورنيش النيل': {'lat': 30.0500, 'lng': 31.2400},
    // Add more stops from bus data as needed
  };

  @override
  void initState() {
    super.initState();
    if (!SearchPanel.disableNotificationsForTests) {
      _initializeNotificationService();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTripState();
    });
  }

  @override
  void dispose() {
    _saveTripState();
    startController.dispose();
    endController.dispose();
    searchController.dispose();
    _debounce?.cancel();
    _notificationService?.stopMonitoring();
    super.dispose();
  }

  Future<void> _initializeNotificationService() async {
    // Get all stops from bus data
    final allStops = <String>[];
    for (var bus in widget.busLinesData) {
      final stops = bus['stops']?.split(' - ') ?? [];
      allStops.addAll(stops);
    }

    // Create unique stops list
    final uniqueStops = allStops.toSet().toList();

    // Convert to Stop objects with real coordinates where available
    final stops = uniqueStops.map((name) {
      final normalizedName = name.trim().toLowerCase();
      final coords = _stopCoordinates.entries.firstWhere(
        (entry) => normalizedName.contains(entry.key.toLowerCase()) || entry.key.toLowerCase().contains(normalizedName),
        orElse: () => MapEntry('', {'lat': 0.0, 'lng': 0.0}),
      );
      return Stop(
        name: name,
        lat: coords.value['lat'] ?? 0.0,
        lng: coords.value['lng'] ?? 0.0,
      );
    }).toList();

    _notificationService = UltimateLocationNotificationService(stops: stops);
    await _notificationService!.initialize();
  }

  Future<void> _loadTripState() async {
    final data = await AppStateService.loadTrip();
    if (mounted) {
      startController.text = data['start'] ?? '';
      endController.text = data['end'] ?? '';
      _notificationsEnabled = data['notificationEnabled'] ?? false;
      setState(() {});
      // Service self-restores from prefs; restart UI sync if enabled
      if (_notificationsEnabled && endController.text.isNotEmpty && _notificationService != null) {
        await _notificationService!.startMonitoringForDestination(endController.text);
      }
    }
  }

  Future<void> _saveTripState() async {
    await AppStateService.saveTrip(
      start: startController.text,
      end: endController.text,
      targetStation: endController.text,
      notificationEnabled: _notificationsEnabled,
    );
  }

  void _onFieldChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch();
    });
  }

  void _performSearch() {
    final start = startController.text.trim();
    final end = endController.text.trim();
    final searchTerm = searchController.text.trim();
    
    if (start.isNotEmpty || end.isNotEmpty || searchTerm.isNotEmpty) {
      searchBuses(showAd: false);
    }
  }

  void _onSearchChanged(String value) {
    _onFieldChanged(value);
  }

  // Method to handle search button press with interstitial ad
  void _onSearchButtonPressed() {
    // Show interstitial ad when user presses search button
    AdService.showInterstitialAdAfterSearch(delayMs: 500);
    searchBuses(showAd: true);
  }

  void searchBuses({bool showAd = false}) async {
    final start = startController.text.trim();
    final end = endController.text.trim();
    final searchTerm = searchController.text.trim();

    if (start.isEmpty && end.isEmpty && searchTerm.isEmpty) {
      widget.onSearch([], false);
      return;
    }

    // Show loading state
    widget.onSearch([], true);

    // Save points after search
    unawaited(_saveTripState());

    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    final filteredLines = await compute(
      searchBusLines,
      FilterParams(
        busLinesData: widget.busLinesData,
        start: start,
        end: end,
        searchTerm: searchTerm,
        dictionary: StationTranslationService().getDictionary(),
      ),
    );

    widget.onSearch(filteredLines, false);

    if (filteredLines.isNotEmpty && context.mounted) {
      try {
        final historyProvider = Provider.of<HistoryProvider>(context, listen: false);
        historyProvider.addTrip(TripHistory(
          timestamp: DateTime.now(),
          route: searchTerm.isNotEmpty ? searchTerm : (filteredLines.length == 1 ? 'خط ${filteredLines.first.routeNumber}' : 'بحث مخصص'),
          from: start.isNotEmpty ? start : 'موقعك الحالى',
          to: end.isNotEmpty ? end : 'غير محدد',
        ));
      } catch (e) {
        debugPrint('Error saving to history: $e');
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Theme.of(context).cardColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(26),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  TextField(
                    controller: startController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Starting Point' : 'نقطة الانطلاق',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(128),
                      ),
                      prefixIcon: const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                      ),
                      border: InputBorder.none,
                    ),
                    textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                    onChanged: (_) => _onFieldChanged(_.trim()),
                    autofocus: false,
                    enabled: true,
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: endController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Destination' : 'نقطة الوصول',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(128),
                      ),
                      prefixIcon: const Icon(
                        Icons.flag,
                        color: Colors.green,
                      ),
                      border: InputBorder.none,
                    ),
                    textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                    onChanged: (_) => _onFieldChanged(_.trim()),
                  ),
                  const Divider(height: 1),
                  TextField(
                    controller: searchController,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search by number or stops' : 'ابحث برقم الخط أو المحطات',
                      hintStyle: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withAlpha(128),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                      ),
                      border: InputBorder.none,
                    ),
                    textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
                    onChanged: _onSearchChanged,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _onSearchButtonPressed,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    isEn ? 'Search for Buses' : 'ابحث عن الحافلات',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

            ],
          ),
        ],
      ),
    );
  }
}

class FilterParams {
  final List<Map<String, String>> busLinesData;
  final String start;
  final String end;
  final String searchTerm;
  final Map<String, String> dictionary;

  FilterParams({
    required this.busLinesData,
    required this.start,
    required this.end,
    required this.searchTerm,
    required this.dictionary,
  });
}

List<BusLine> searchBusLines(FilterParams params) {
  // Create an index for faster lookup
  final reverseDictionary = <String, List<String>>{};
  params.dictionary.forEach((ar, en) {
    final enLower = en.toLowerCase();
    reverseDictionary.putIfAbsent(enLower, () => []).add(ar.toLowerCase());
  });

  return params.busLinesData
      .where((bus) {
        final stops = bus['stops']!.toLowerCase();
        final routeNumber = bus['routeNumber']!.toLowerCase();
        final busType = bus['type']!.toLowerCase();
        
        final startTerm = params.start.toLowerCase();
        final endTerm = params.end.toLowerCase();
        final searchTerm = params.searchTerm.toLowerCase();

        // Helper function for fuzzy matching (Arabic original OR English transliteration)
        bool matches(String text, String term) {
          if (term.isEmpty) return true;
          if (text.contains(term)) return true;
          
          // Check if the term is a transliteration in the dictionary
          for (var entry in reverseDictionary.entries) {
            if (term.contains(entry.key) || entry.key.contains(term)) {
              for (var arVal in entry.value) {
                if (text.contains(arVal)) return true;
              }
            }
          }
          return false;
        }

        final matchesStart = matches(stops, startTerm);
        final matchesEnd = matches(stops, endTerm);
        final matchesSearch = matches(stops, searchTerm) || 
                             routeNumber.contains(searchTerm) || 
                             busType.contains(searchTerm);

        return matchesStart && matchesEnd && matchesSearch;
      })
      .map((data) => BusLine.fromMap(data))
      .toList();
}
