import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_history.dart';

class HistoryProvider with ChangeNotifier {
  List<TripHistory> _trips = [];
  final String _storageKey = 'search_history';

  List<TripHistory> get trips => _trips;

  // Load history on initialization
  Future<void> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      
      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _trips = jsonList.map((item) => TripHistory.fromJson(item)).toList();
        
        // Sort by timestamp (newest first)
        _trips.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    }
  }

  // Add a trip and persist
  Future<void> addTrip(TripHistory trip) async {
    // Check for duplicates (same from and to)
    final existingIndex = _trips.indexWhere(
      (t) => t.from == trip.from && t.to == trip.to && t.route == trip.route
    );

    if (existingIndex != -1) {
      _trips.removeAt(existingIndex);
    }

    // Add at the beginning (newest first)
    _trips.insert(0, trip);

    // Limit history size to 30 items
    if (_trips.length > 30) {
      _trips = _trips.sublist(0, 30);
    }

    notifyListeners();
    await _saveToStorage();
  }

  // Remove a single item
  Future<void> removeTrip(int index) async {
    if (index >= 0 && index < _trips.length) {
      _trips.removeAt(index);
      notifyListeners();
      await _saveToStorage();
    }
  }

  // Clear all history
  Future<void> clearHistory() async {
    _trips.clear();
    notifyListeners();
    await _saveToStorage();
  }

  // Private helper to save to storage
  Future<void> _saveToStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(_trips.map((t) => t.toJson()).toList());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      debugPrint('Error saving history: $e');
    }
  }

  List<TripHistory> getTripsForDay(DateTime day) {
    return _trips.where((trip) {
      return trip.timestamp.year == day.year &&
             trip.timestamp.month == day.month &&
             trip.timestamp.day == day.day;
    }).toList();
  }
}
