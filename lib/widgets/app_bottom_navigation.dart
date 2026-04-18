import 'package:flutter/material.dart';

class AppBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const AppBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'الرئيسية',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.favorite),
          label: 'المفضلة',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history),
          label: 'السجل',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.settings),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}
