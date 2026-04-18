import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' as intl;
import '../providers/history_provider.dart';
import '../models/trip_history.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load history when screen is opened just in case
    Future.microtask(() => context.read<HistoryProvider>().loadHistory());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final historyProvider = Provider.of<HistoryProvider>(context);
    final trips = historyProvider.trips;

    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل البحث', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          if (trips.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
              onPressed: () => _showClearDialog(context, historyProvider),
              tooltip: 'مسح الكل',
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.primaryColor.withOpacity(0.05),
            ],
          ),
        ),
        child: trips.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.history_toggle_off, size: 80, color: Colors.grey.withOpacity(0.5)),
                    const SizedBox(height: 16),
                    const Text(
                      'سجل البحث فارغ حالياً',
                      style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                itemCount: trips.length,
                itemBuilder: (context, index) {
                  final trip = trips[index];
                  return _buildHistoryItem(context, trip, index, historyProvider);
                },
              ),
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, TripHistory trip, int index, HistoryProvider provider) {
    final theme = Theme.of(context);
    final dateStr = intl.DateFormat('yyyy/MM/dd - hh:mm a', 'en_US').format(trip.timestamp);

    return Dismissible(
      key: Key('history_${trip.timestamp.millisecondsSinceEpoch}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => provider.removeTrip(index),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: CircleAvatar(
            backgroundColor: theme.primaryColor.withOpacity(0.1),
            child: Icon(Icons.search, color: theme.primaryColor),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  '${trip.from} ➔ ${trip.to}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                trip.route,
                style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w500),
                textDirection: TextDirection.rtl,
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          onTap: () {
            // Optional: Re-trigger search or fill fields
            Navigator.pop(context, trip);
          },
        ),
      ),
    );
  }

  void _showClearDialog(BuildContext context, HistoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('مسح السجل', textDirection: TextDirection.rtl),
        content: const Text('هل أنت متأكد من مسح جميع عمليات البحث المحفوظة؟', textDirection: TextDirection.rtl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              provider.clearHistory();
              Navigator.pop(ctx);
            },
            child: const Text('مسح الكل', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
