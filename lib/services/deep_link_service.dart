import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import '../models/bus_line.dart';
import '../data/bus_data.dart';
import '../services/cache_service.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription? _linkSubscription;
  final _deepLinkController = StreamController<BusLine?>.broadcast();
  
  // Store initial URI for handling after stream is set up
  Uri? _initialUri;

  Stream<BusLine?> get deepLinkStream => _deepLinkController.stream;

  /// Initialize deep link handling
  void init(BuildContext context) {
    // Handle initial link (when app is opened from a link)
    _handleInitialLink(context);

    // Handle links while app is running
    _linkSubscription = _appLinks.uriLinkStream.listen((Uri? uri) {
      // Skip if we already handled this URI
      if (uri != null && (_initialUri == null || uri.toString() != _initialUri.toString())) {
        _handleLink(context, uri);
      }
    }, onError: (err) {
      debugPrint('Deep link error: $err');
    });
  }

  /// Handle the initial link when app is first opened
  Future<void> _handleInitialLink(BuildContext context) async {
    try {
      // For app_links v3.x, get the initial link from the first stream event
      // We'll capture it in the stream listener
      // For now, we'll handle it differently - check if there's an initial URI
      // by listening to the stream with a timeout
      final completer = Completer<Uri?>();
      
      final subscription = _appLinks.uriLinkStream.listen((Uri? uri) {
        if (!completer.isCompleted) {
          completer.complete(uri);
        }
      });
      
      // Wait for first URI with timeout
      final uri = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => null,
      );
      
      await subscription.cancel();
      
      if (uri != null) {
        _initialUri = uri;
        _handleLink(context, uri);
      }
    } catch (e) {
      debugPrint('Error getting initial deep link: $e');
    }
  }

  /// Handle incoming deep link
  void _handleLink(BuildContext context, Uri? uri) {
    if (uri == null) return;

    debugPrint('Received deep link: $uri');

    // Check if this is a line deep link
    // Supported formats:
    // - enjaz://line/101
    // - https://enjaz.app/line/101
    // - https://enjaz.app/line/101?type=اتوبيس
    
    if (uri.pathSegments.isNotEmpty) {
      final firstSegment = uri.pathSegments.first;
      
      if (firstSegment == 'line' && uri.pathSegments.length >= 2) {
        final routeNumber = uri.pathSegments[1];
        final type = uri.queryParameters['type'];
        
        _navigateToLine(context, routeNumber, type);
      }
    }
  }

  /// Navigate to the bus line details screen
  Future<void> _navigateToLine(BuildContext context, String routeNumber, String? type) async {
    final busLine = await findBusLineByRouteNumber(routeNumber, type);
    
    if (busLine != null) {
      _deepLinkController.add(busLine);
      
      // Navigate to the line details screen
      if (context.mounted) {
        Navigator.pushNamed(
          context,
          '/line_details',
          arguments: busLine,
        );
      }
    } else {
      debugPrint('Bus line not found: $routeNumber');
    }
  }

  /// Find a bus line by route number
  /// This searches through both cached lines and default data
  Future<BusLine?> findBusLineByRouteNumber(String routeNumber, String? type) async {
    // First, try to find in cached data
    final cachedLines = await UltimateCacheService.getCachedBusLines();
    if (cachedLines != null && cachedLines.isNotEmpty) {
      BusLine? found = _findLineInList(cachedLines, routeNumber, type);
      if (found != null) return found;
    }

    // Then try the default data
    BusLine? found = _findLineInList(
      busLinesData.map((e) => BusLine.fromMap(e)).toList(),
      routeNumber,
      type,
    );
    
    return found;
  }

  /// Find a line in a list of bus lines
  BusLine? _findLineInList(List<BusLine> lines, String routeNumber, String? type) {
    // First, try exact match with route number and type
    if (type != null) {
      try {
        return lines.firstWhere(
          (line) => line.routeNumber == routeNumber && line.type == type,
        );
      } catch (_) {
        // Not found with exact type match
      }
    }

    // Try exact match with route number only
    try {
      return lines.firstWhere(
        (line) => line.routeNumber == routeNumber,
      );
    } catch (_) {
      // Not found
    }

    // Try partial match (route number contains the search term)
    try {
      return lines.firstWhere(
        (line) => line.routeNumber.toLowerCase().contains(routeNumber.toLowerCase()),
      );
    } catch (_) {
      // Not found
    }

    return null;
  }

  /// Generate a shareable deep link for a bus line
  String generateDeepLink(BusLine busLine) {
    // Generate both app link and web link
    final appLink = 'enjaz://line/${busLine.routeNumber}';
    final webLink = 'https://enjaz.app/line/${busLine.routeNumber}';
    
    // Return the web link as it's more universal
    return webLink;
  }

  /// Dispose the service
  void dispose() {
    _linkSubscription?.cancel();
    _deepLinkController.close();
  }
}

// Singleton instance
final deepLinkService = DeepLinkService();
