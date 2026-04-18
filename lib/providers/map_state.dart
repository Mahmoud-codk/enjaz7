import 'package:flutter/material.dart';
import '../models/location_point.dart';

// 🔥 Provider لتقليل الـ rebuilds (الحل #3)
class MapState with ChangeNotifier {
  List<LocationPoint> nearbyRoutes = [];
  bool isComputing = false;
  String status = 'جاري التحميل...';

  void updateNearby(List<LocationPoint> routes) {
    nearbyRoutes = routes;
    notifyListeners();
  }

  void setComputing(bool computing) {
    isComputing = computing;
    notifyListeners();
  }

  void updateStatus(String newStatus) {
    status = newStatus;
    notifyListeners();
  }
}
