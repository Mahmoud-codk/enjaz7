import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:enjaz7/widgets/search_panel.dart';

void main() {
  group('SearchPanel Tests', () {
    // Prevent SearchPanel from initializing platform notifications during tests.
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      // disable notifications to avoid flutter_local_notifications initialization errors
      // during widget tests
      // ignore: cascade_invocations
      // set static flag on the widget
      // (imported at top)
      SearchPanel.disableNotificationsForTests = true;
    });

    final testBusLinesData = [
      {
        'routeNumber': '123',
        'type': 'اتوبيس',
        'stops': 'القاهرة . الجيزة . المعادي',
        'emptySeats': '5',
      },
      {
        'routeNumber': '456',
        'type': 'ميني باص',
        'stops': 'المتحف . التحرير . العتبة',
        'emptySeats': '3',
      },
      {
        'routeNumber': '789',
        'type': 'اتوبيس',
        'stops': 'مدينة نصر . مصر الجديدة . الزمالك',
        'emptySeats': '8',
      },
    ];

    testWidgets('Search by route number', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPanel(
              busLinesData: testBusLinesData,
              onSearch: (results, isLoading) {
                if (!isLoading) {
                  expect(results.length, 1);
                  expect(results[0].routeNumber, '123');
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField).last, '123');
      await tester.pumpAndSettle();
    });

    testWidgets('Search by bus type', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPanel(
              busLinesData: testBusLinesData,
              onSearch: (results, isLoading) {
                if (!isLoading) {
                  expect(results.length, 2);
                  expect(results.every((line) => line.type == 'اتوبيس'), true);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField).last, 'اتوبيس');
      await tester.pumpAndSettle();
    });

    testWidgets('Search by stop name', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPanel(
              busLinesData: testBusLinesData,
              onSearch: (results, isLoading) {
                if (!isLoading) {
                  expect(results.length, 1);
                  expect(results[0].routeNumber, '456');
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query
      await tester.enterText(find.byType(TextField).last, 'المتحف');
      await tester.pumpAndSettle();
    });

    testWidgets('Empty search returns all results', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPanel(
              busLinesData: testBusLinesData,
              onSearch: (results, isLoading) {
                if (!isLoading) {
                  expect(results.length, 3);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Clear search field
      await tester.enterText(find.byType(TextField).last, '');
      await tester.pumpAndSettle();
    });

    testWidgets('No results found', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SearchPanel(
              busLinesData: testBusLinesData,
              onSearch: (results, isLoading) {
                if (!isLoading) {
                  expect(results.isEmpty, true);
                }
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter non-matching search query
      await tester.enterText(find.byType(TextField).last, 'nonexistent');
      await tester.pumpAndSettle();
    });
  });
}
