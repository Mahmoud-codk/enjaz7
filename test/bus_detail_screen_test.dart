import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:enjaz7/screens/bus_line_details_screen.dart';
import 'package:enjaz7/models/bus_line.dart';
import 'package:provider/provider.dart';
import 'package:enjaz7/providers/favorites_provider.dart';

void main() {
  testWidgets('BusLineDetailsScreen displays bus route number', (WidgetTester tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Arrange: Create a BusLine instance
    final busLine = BusLine(
      routeNumber: '101',
      type: 'City Bus',
      stops: ['Stop 1', 'Stop 2', 'Stop 3'],
      emptySeats: 10,
    );

    // Pump the BusLineDetailsScreen widget with the busLine wrapped with providers
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(testMode: true),
          child: BusLineDetailsScreen(
            busLine: busLine,
          ),
        ),
      ),
    );

    // Assert: Verify the route number is displayed
    expect(find.text('خط 101'), findsOneWidget);
  });

  testWidgets('BusLineDetailsScreen displays hardcoded stops in StopTimeline', (WidgetTester tester) async {
    // Arrange
    final busLine = BusLine(
      routeNumber: '101',
      type: 'City Bus',
      stops: ['Stop 1', 'Stop 2', 'Stop 3', 'Stop 4'],
      emptySeats: 5,
    );

    // Act: wrap with provider
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(testMode: true),
          child: BusLineDetailsScreen(
            busLine: busLine,
          ),
        ),
      ),
    );

  // Verify that stops from the provided BusLine are displayed
  expect(find.text('Stop 1'), findsWidgets);
  expect(find.text('Stop 4'), findsWidgets);
  });

  testWidgets('BusLineDetailsScreen has share and favorite buttons', (WidgetTester tester) async {
    // Arrange
    final busLine = BusLine(
      routeNumber: '101',
      type: 'أوبيس',
      stops: ['Stop 1', 'Stop 2'],
      emptySeats: 5,
    );

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(testMode: true),
          child: BusLineDetailsScreen(
            busLine: busLine,
          ),
        ),
      ),
    );

    // Assert
    expect(find.byIcon(Icons.share), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsOneWidget);
  });

  testWidgets('BusLineDetailsScreen has "أوبيس" button', (WidgetTester tester) async {
    // Arrange
    final busLine = BusLine(
      routeNumber: '101',
      type: 'أوبيس',
      stops: ['Stop 1', 'Stop 2'],
      emptySeats: 5,
    );

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(testMode: true),
          child: BusLineDetailsScreen(
            busLine: busLine,
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('أوبيس'), findsOneWidget);
  });

  testWidgets('BusLineDetailsScreen has "عرض على الخريطة" button', (WidgetTester tester) async {
    // Arrange
    final busLine = BusLine(
      routeNumber: '101',
      type: 'City Bus',
      stops: ['Stop 1', 'Stop 2'],
      emptySeats: 5,
    );

    // Act
    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider(
          create: (_) => FavoritesProvider(testMode: true),
          child: BusLineDetailsScreen(
            busLine: busLine,
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('عرض على الخريطة'), findsOneWidget);
  });
}
