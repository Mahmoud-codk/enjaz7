import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:enjaz7/screens/bus_line_details_screen.dart';
import 'package:enjaz7/models/bus_line.dart';
import 'package:enjaz7/providers/favorites_provider.dart';

void main() {
  group('BusLineDetailsScreen Tests', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    testWidgets('Displays correct route information', (
      WidgetTester tester,
    ) async {
      final busLine = BusLine(
        routeNumber: '123',
        type: 'اتوبيس',
        stops: ['محطة أ', 'محطة ب', 'محطة ج'],
        emptySeats: 5,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (context) => FavoritesProvider(testMode: true),
            child: BusLineDetailsScreen(busLine: busLine),
          ),
        ),
      );

      await tester.pumpAndSettle();

  // Verify route number is displayed
  expect(find.text('خط 123'), findsOneWidget);

  // Verify bus type is displayed
  expect(find.text('اتوبيس'), findsOneWidget);

  // Verify start and end stops
  expect(find.text('محطة أ'), findsWidgets);
  expect(find.text('محطة ج'), findsWidgets);
    });

    testWidgets('Favorite button toggles correctly', (
      WidgetTester tester,
    ) async {
      final busLine = BusLine(
        routeNumber: '456',
        type: 'ميني باص',
        stops: ['محطة 1', 'محطة 2'],
        emptySeats: 3,
      );

      final favoritesProvider = FavoritesProvider(testMode: true);

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider.value(
            value: favoritesProvider,
            child: BusLineDetailsScreen(busLine: busLine),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially should show empty heart
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);

      // Tap favorite button (second IconButton in AppBar actions)
      await tester.tap(find.byType(IconButton).at(1));
      await tester.pumpAndSettle();

      // Should now show filled heart
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsNothing);

      // Tap again to unfavorite
      await tester.tap(find.byType(IconButton).at(1));
      await tester.pumpAndSettle();

      // Should show empty heart again
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
    });

    testWidgets('Share button is present', (WidgetTester tester) async {
      final busLine = BusLine(
        routeNumber: '789',
        type: 'اتوبيس',
        stops: ['محطة أ', 'محطة ب'],
        emptySeats: 2,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (context) => FavoritesProvider(testMode: true),
            child: BusLineDetailsScreen(busLine: busLine),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify share button is present
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('Displays all stops in timeline', (WidgetTester tester) async {
      final busLine = BusLine(
        routeNumber: '100',
        type: 'اتوبيس',
        stops: ['محطة 1', 'محطة 2', 'محطة 3', 'محطة 4'],
        emptySeats: 8,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider(
            create: (context) => FavoritesProvider(testMode: true),
            child: BusLineDetailsScreen(busLine: busLine),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all stops are displayed
    expect(find.text('محطة 1'), findsWidgets);
    expect(find.text('محطة 2'), findsOneWidget);
    expect(find.text('محطة 3'), findsOneWidget);
    expect(find.text('محطة 4'), findsWidgets);
    });
  });
}
