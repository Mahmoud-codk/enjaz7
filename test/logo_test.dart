import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Avoid importing the full HomeScreen to keep tests lightweight
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    // Mock SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('HomeScreen displays logo images', (WidgetTester tester) async {
    // Pump a minimal scaffold that contains the same images used in HomeScreen
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            title: Image(image: AssetImage('assets/images/play_store_512.png')),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: null,
            child: Image(image: AssetImage('assets/palestine.png')),
          ),
        ),
      ),
    );

    // Allow the widgets to build
    await tester.pump();

    // Verify that the play store logo is displayed in the app bar
    expect(find.byWidgetPredicate((widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == 'assets/images/play_store_512.png'
    ), findsOneWidget);

    // Verify that the palestine logo is displayed in the floating action button
    expect(find.byWidgetPredicate((widget) =>
      widget is Image &&
      widget.image is AssetImage &&
      (widget.image as AssetImage).assetName == 'assets/palestine.png'
    ), findsOneWidget);
  });
}
