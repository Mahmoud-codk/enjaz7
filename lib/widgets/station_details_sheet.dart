import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
import '../models/stop.dart';
import 'station_map_dialog.dart';

class StationDetailsSheet extends StatelessWidget {
  final Stop stop;

  const StationDetailsSheet({super.key, required this.stop});

  Future<void> _openInMaps(double latitude, double longitude) async {
    final url =
        'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  void _copyCoordinates(
    BuildContext context,
    double latitude,
    double longitude,
  ) {
    Clipboard.setData(
      ClipboardData(text: 'Latitude: $latitude, Longitude: $longitude'),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم نسخ الإحداثيات إلى الحافظة')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 5),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.blue, size: 28),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  stop.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'الإحداثيات:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: Colors.green, size: 20),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'خط العرض: ${stop.latitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'خط الطول: ${stop.longitude.toStringAsFixed(5)}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _copyCoordinates(context, stop.latitude, stop.longitude),
                icon: const Icon(Icons.copy, size: 18),
                label: const Text('نسخ الإحداثيات'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => StationMapDialog(stop: stop),
                  );
                },
                icon: const Icon(Icons.map, size: 18),
                label: const Text('عرض الخريطة'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 40),
              backgroundColor: Colors.grey[200],
              foregroundColor: Colors.black,
            ),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }
}
