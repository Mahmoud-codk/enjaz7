import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter/services.dart';
import '../models/bus_line.dart';
import '../screens/bus_line_details_screen.dart';
import '../providers/favorites_provider.dart';
import '../utils/ultimate_url_launcher.dart';

/// A compact, defensive implementation of the bus list and card.
/// - Avoids RenderFlex overflow by using Flexible/Expanded and Wrap.
/// - Guards image loading with errorBuilder so missing assets don't crash.
/// - Keeps imports at the top and contains a single set of declarations.
class UltimateBusList extends StatelessWidget {
  final List<BusLine> busLines;
  final bool isLoading;

  const UltimateBusList(
      {super.key, required this.busLines, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    if (isLoading) {
      return ListView.builder(
        itemCount: 6,
        padding: const EdgeInsets.all(16),
        itemBuilder: (_, __) => const BusCardShimmer(),
      );
    }

    if (busLines.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Lottie is optional; check asset existence and fallback to an icon if missing.
            FutureBuilder<bool>(
              future: rootBundle
                  .loadString('assets/animations/no_bus.json')
                  .then((_) => true)
                  .catchError((_) => false),
              builder: (context, snapshot) {
                if (snapshot.data == true) {
                  return Lottie.asset('assets/animations/no_bus.json',
                      height: 160);
                }
                return Container(
                  height: 160,
                  alignment: Alignment.center,
                  child: const Icon(Icons.directions_bus,
                      size: 80, color: Colors.grey),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(isEn ? 'No matching buses found' : 'مفيش حافلات تطابق البحث',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
                isEn
                    ? 'Try another word or change filters'
                    : 'جرب كلمة تانية أو غيّر الفلتر',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SizedBox(
      height: MediaQuery.of(context).size.height *
          0.6, // Fixed height to prevent infinite scroll issues
      child: ListView.builder(
        itemCount: busLines.length,
        padding: const EdgeInsets.only(bottom: 80, top: 8),
        itemBuilder: (context, index) {
          final busLine = busLines[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: UltimateBusCard(busLine: busLine),
          );
        },
      ),
    );
  }
}

class UltimateBusCard extends StatelessWidget {
  final BusLine busLine;

  const UltimateBusCard({super.key, required this.busLine});

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoritesProvider>();
    final isFavorite = favorites.isFavorite(busLine);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BusLineDetailsScreen(busLine: busLine))),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, isFavorite),
              const SizedBox(height: 12),
              _buildStopsPreview(context),
              const SizedBox(height: 12),
              _buildActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isFavorite) {
    final isPalestineLine = busLine.routeNumber == '1948';
    final isEn = Localizations.localeOf(context).languageCode == 'en';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            _getBusImage(busLine.type),
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (ctx, err, st) => Container(
              width: 56,
              height: 56,
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(Icons.directions_bus,
                  color: Colors.grey, size: 28),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: _getLineGradient(busLine.type)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        isPalestineLine
                            ? (isEn ? 'Free Palestine' : 'خط فلسطين حرة')
                            : (isEn
                                ? 'Route ${busLine.routeNumber}'
                                : 'خط ${busLine.routeNumber}'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.timer, size: 14, color: Colors.grey),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isEn
                          ? '${busLine.stops.length} Stops • ~${_estimateDuration(busLine.stops.length)} min'
                          : '${busLine.stops.length} محطة • ~${_estimateDuration(busLine.stops.length)} دقيقة',
                      style:
                          const TextStyle(color: Colors.black87, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(isFavorite ? Icons.favorite : Icons.favorite_border,
                key: ValueKey(isFavorite),
                color: isFavorite ? Colors.red : Colors.grey),
          ),
          onPressed: () {
            final favs = Provider.of<FavoritesProvider>(context, listen: false);
            favs.toggleFavorite(busLine);
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(isEn
                    ? (isFavorite
                        ? 'Removed from favorites'
                        : 'Added to favorites')
                    : (isFavorite
                        ? 'تمت الإزالة من المفضلة'
                        : 'تمت الإضافة إلى المفضلة'))));
          },
        ),
      ],
    );
  }

  Widget _buildStopsPreview(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final localizedStops = busLine.getLocalizedStops(locale);

    return Row(
      children: [
        Icon(Icons.arrow_forward, color: _getDirectionColor(busLine.direction)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _formatStopsPreview(localizedStops),
            style: const TextStyle(fontSize: 14, height: 1.4),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActions(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final isEn = locale.languageCode == 'en';
    final localizedStops = busLine.getLocalizedStops(locale);

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        TextButton.icon(
          onPressed: () => UltimateLinkLauncher.share(
              isEn
                  ? 'Check out route ${busLine.routeNumber}: ${localizedStops.first} → ${localizedStops.last}'
                  : 'شوف خط ${busLine.routeNumber}: ${localizedStops.first} → ${localizedStops.last}',
              url: 'https://busguide.eg/line/${busLine.routeNumber}'),
          icon: const Icon(Icons.share, size: 18),
          label: Text(isEn ? 'Share Route' : 'شارك الخط'),
        ),
        TextButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BusLineDetailsScreen(busLine: busLine)),
          ),
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
          label: Text(isEn ? 'Details' : 'التفاصيل'),
        ),
      ],
    );
  }

  String _getBusImage(String type) {
    // Many specific bus images are not present in the repo; use the app icon as a safe fallback.
    return 'assets/images/play_store_512.png';
  }

  List<Color> _getLineGradient(String type) {
    switch (type.toLowerCase()) {
      case 'اتوبيس':
        return [Colors.red.shade700, Colors.redAccent];
      case 'ميني باص':
        return [Colors.green.shade700, Colors.greenAccent];
      case 'سريع':
        return [Colors.blue.shade700, Colors.blueAccent];
      default:
        return [Colors.grey.shade600, Colors.grey.shade400];
    }
  }

  Color _getDirectionColor(String direction) =>
      direction == 'ذهاب' ? Colors.green : Colors.orange;

  String _estimateDuration(int stops) => (stops * 2.5).toInt().toString();

  String _formatStopsPreview(List<String> stops) {
    if (stops.isEmpty) return '';
    if (stops.length <= 3) return stops.join(' → ');
    return '${stops.first} → ... → ${stops.last}';
  }
}

class BusCardShimmer extends StatelessWidget {
  const BusCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 56, height: 56, color: Colors.grey[300]),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 120, height: 20, color: Colors.grey[300]),
                      const SizedBox(height: 8),
                      Container(width: 80, height: 14, color: Colors.grey[300]),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
                width: double.infinity, height: 14, color: Colors.grey[300]),
            const SizedBox(height: 8),
            Container(width: 200, height: 14, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
}
