import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:lottie/lottie.dart';
import '../widgets/search_panel.dart';
import '../models/bus_line.dart';
import '../data/bus_data.dart';
import '../providers/map_provider.dart';
import '../providers/favorites_provider.dart';

class UltimateMapScreen extends StatefulWidget {
  const UltimateMapScreen({super.key});

  @override
  State<UltimateMapScreen> createState() => _UltimateMapScreenState();
}

class _UltimateMapScreenState extends State<UltimateMapScreen> with TickerProviderStateMixin {
  late List<BusLine> filteredBusLines;
  bool isSearching = false;
  late AnimationController _sheetController;
  late Animation<double> _sheetAnimation;

  @override
  void initState() {
    super.initState();
    // Grouping lines to avoid redundant entries in the UI
    final Map<String, BusLine> groupedLines = {};
    for (var map in busLinesData) {
      final line = BusLine.fromMap(Map<String, dynamic>.from(map));
      final key = "${line.routeNumber}_${line.type}";
      if (!groupedLines.containsKey(key)) {
        groupedLines[key] = line;
      }
    }
    filteredBusLines = groupedLines.values.toList();

    _sheetController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sheetAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MapProvider>().initializeWithBusLines(filteredBusLines);
    });
  }

  void updateSearchResults(List<BusLine> results, bool searching) {
    setState(() {
      filteredBusLines = results;
      isSearching = searching;
    });
    context.read<MapProvider>().filterBusLines(results);
    if (!searching && results.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) context.read<MapProvider>().centerOnLines();
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    context.read<MapProvider>().setMapController(controller);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) context.read<MapProvider>().centerOnLines();
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Row(
          children: [
            Image.asset('assets/images/play_store_512.png', width: 32, height: 32),
            const SizedBox(width: 8),
            const Text('خريطة الحافلات التفاعلية', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        centerTitle: true,
        actions: [
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) => IconButton(
              icon: Icon(mapProvider.showAllLines ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                mapProvider.toggleShowAllLines();
                if (mapProvider.showAllLines) mapProvider.centerOnLines();
              },
              tooltip: mapProvider.showAllLines ? 'إخفاء الكل' : 'عرض الكل',
            ),
          ),
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => context.read<MapProvider>().goToUserLocation(),
            tooltip: 'موقعي',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) => GoogleMap(
              initialCameraPosition: mapProvider.cameraPosition,
              onMapCreated: _onMapCreated,
              onCameraMove: (pos) => mapProvider.updateCameraPosition(pos),
              markers: mapProvider.markers,
              polylines: mapProvider.polylines,
              myLocationEnabled: false, // Use custom bus icon marker from provider instead of blue dot
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              trafficEnabled: true,
              mapToolbarEnabled: false,
            ),
          ),

          // Search Panel
          Positioned(
            top: 100,
            left: 16,
            right: 16,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              child: SearchPanel(
                onSearch: updateSearchResults,
                busLinesData: busLinesData.map((e) => Map<String, String>.from(e)).toList(),
              ),
            ),
          ),

          // Draggable Bottom Sheet
          AnimatedBuilder(
            animation: _sheetAnimation,
            builder: (context, child) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  onVerticalDragUpdate: (details) {
                    _sheetController.value -= details.primaryDelta! / (context.size!.height * 0.7);
                  },
                  onVerticalDragEnd: (details) {
                    if (_sheetController.value > 0.6) {
                      _sheetController.forward();
                    } else {
                      _sheetController.reverse();
                    }
                  },
                  child: Transform.translate(
                    offset: Offset(0, (1 - _sheetAnimation.value) * 200),
                    child: Container(
                      height: MediaQuery.of(context).size.height * 0.7 * _sheetAnimation.value,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[900] : Colors.white,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Handle
                          Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 50,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'الخطوط المعروضة (${filteredBusLines.length})',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          // Filters
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _filterChip('الكل', null),
                                  _filterChip('أتوبيس', 'اتوبيس'),
                                  _filterChip('ميني باص', 'ميني باص'),
                                  _filterChip('سريع', 'سريع'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // List
                          Expanded(
                            child: BusLinesDraggableList(
                              busLines: filteredBusLines,
                              onLineTap: (line) {
                                context.read<MapProvider>().selectLine(line);
                                context.read<MapProvider>().centerOnLines();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          // Legend
          Positioned(
            top: 180,
            right: 16,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('دليل الألوان', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    _legendItem('نقطة البداية', Colors.green),
                    _legendItem('نقطة النهاية', Colors.red),
                    _legendItem('محطة عادية', Colors.blue),
                    _legendItem('حافلة حية', Colors.orange),
                  ],
                ),
              ),
            ),
          ),

          // Palestine Flag
          Positioned(
            bottom: 120,
            right: 16,
            child: GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('من النهر إلى البحر... فلسطين حرة'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 3),
                  ),
                );
              },
              child: Image.asset('assets/palestine.png', width: 70),
            ),
          ),

          // Loading
          Consumer<MapProvider>(
            builder: (context, mapProvider, child) {
              if (mapProvider.isLoading) {
                return Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Lottie.asset('assets/animations/bus_map_loading.json', width: 200),
                    ),
                  ),
                );
              }
              return const SizedBox();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.red,
        onPressed: () => context.read<MapProvider>().centerOnLines(),
        child: const Icon(Icons.center_focus_strong, color: Colors.white),
      ),
    );
  }

  Widget _filterChip(String label, String? type) {
    final mapProvider = context.watch<MapProvider>();
    final isActive = mapProvider.activeFilter == type;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilterChip(
        label: Text(label),
        selected: isActive,
        onSelected: (_) => mapProvider.setFilter(type),
        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
        selectedColor: Theme.of(context).primaryColor,
        labelStyle: TextStyle(color: isActive ? Colors.white : null),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Container(width: 16, height: 16, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class BusLinesDraggableList extends StatelessWidget {
  final List<BusLine> busLines;
  final Function(BusLine) onLineTap;

  const BusLinesDraggableList({super.key, required this.busLines, required this.onLineTap});

  @override
  Widget build(BuildContext context) {
    final mapProvider = context.watch<MapProvider>();
    final favoritesProvider = context.watch<FavoritesProvider>();

    if (busLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset('assets/animations/no_lines.json', width: 150),
            const SizedBox(height: 16),
            const Text('لا توجد خطوط مطابقة', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: busLines.length,
      itemBuilder: (context, index) {
        final line = busLines[index];
        final isSelected = mapProvider.isLineSelected(line);
        final isVisible = mapProvider.isLineVisible(line);
        final isFavorite = favoritesProvider.isFavorite(line);
        final lineColor = mapProvider.getLineColor(line);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          elevation: isSelected ? 8 : 2,
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isVisible ? lineColor : Colors.grey,
              child: Text(line.routeNumber, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            title: Text('خط ${line.routeNumber}', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            subtitle: Text('${line.type} • ${line.stops.length} محطة'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border, color: isFavorite ? Colors.red : Colors.grey),
                  onPressed: () => favoritesProvider.toggleFavorite(line),
                ),
                Switch(
                  value: isVisible,
                  onChanged: (_) => mapProvider.toggleLineSelection(line),
                  activeThumbColor: Theme.of(context).primaryColor,
                ),
              ],
            ),
            onTap: () => onLineTap(line),
          ),
        );
      },
    );
  }
}