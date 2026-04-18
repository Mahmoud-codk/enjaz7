import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import '../utils/responsive.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _service = NotificationService();
  late final ValueNotifier<int> _countListener;

  @override
  void initState() {
    super.initState();
    _countListener = _service.notificationCount;
    _service.initialize();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _refresh() async {
    await _service.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _resetAll() async {
    await _service.reset();
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم مسح جميع الإشعارات')),
    );
  }

  Future<void> _clearHistory() async {
    await _service.clearHistory();
    if (mounted) setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم مسح السجل')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإشعارات'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          ValueListenableBuilder<int>(
            valueListenable: _service.notificationCount,
            builder: (context, count, child) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Stack(
                  children: [
                    const Icon(Icons.notifications, size: 28),
                    if (count > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ValueListenableBuilder<int>(
          valueListenable: _service.notificationCount,
          builder: (context, count, child) {
            if (count == 0) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off,
                      size: Responsive.w(context, 100),
                      color: Colors.grey[400],
                    ),
                    SizedBox(height: Responsive.h(context, 16)),
                    Text(
                      'لا توجد إشعارات',
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 18),
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'ستظهر هنا إشعارات قرب المحطات',
                      style: TextStyle(
                        fontSize: Responsive.sp(context, 14),
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(context, 16),
                vertical: Responsive.h(context, 8),
              ),
              itemCount: _service.notifications.length,
              itemBuilder: (context, index) {
                final notification = _service.notifications[index];
                return Dismissible(
                  key: ValueKey(notification),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) {
                    // Remove from service would require index tracking
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم حذف الإشعار')),
                    );
                  },
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: EdgeInsets.only(right: Responsive.w(context, 20)),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: Responsive.sp(context, 24),
                    ),
                  ),
                  child: Card(
                    margin: EdgeInsets.only(bottom: Responsive.h(context, 12)),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.all(Responsive.w(context, 16)),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        child: Icon(Icons.notifications, color: Colors.blue[700]),
                      ),
                      title: Text(
                        notification.split(' - ')[1],
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        notification.split(' - ')[0],
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: Responsive.sp(context, 12),
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.delete, color: Colors.grey[400]),
                        onPressed: () {
                          // Individual delete logic
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.refresh, color: Colors.blue[700]),
                  title: Text('إعادة تحميل'),
                  onTap: () {
                    Navigator.pop(context);
                    _refresh();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.clear_all, color: Colors.orange[700]),
                  title: Text('مسح السجل'),
                  onTap: () {
                    Navigator.pop(context);
                    _clearHistory();
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red[700]),
                  title: Text('إعادة تعيين الكل'),
                  onTap: () {
                    Navigator.pop(context);
                    _resetAll();
                  },
                ),
              ],
            ),
          ),
        ),
        backgroundColor: Colors.blue[700],
        child: Icon(Icons.more_vert),
      ),
    );
  }
}
