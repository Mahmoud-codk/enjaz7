import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationIcon extends StatelessWidget {
  final VoidCallback? onTap;
  final double size;
  final Color? iconColor;

  const NotificationIcon({
    super.key,
    this.onTap,
    this.size = 30.0,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final service = NotificationService();
    
    return ValueListenableBuilder<int>(
      valueListenable: service.notificationCount,
      builder: (context, count, child) {
        return GestureDetector(
          onTap: onTap,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.notifications_outlined,
                size: size,
                color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              // Red badge (only if count > 0)
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      count > 99 ? '99+' : '$count',
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
    );
  }
}
