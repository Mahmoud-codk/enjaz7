import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:enjaz7/services/location_notification_service.dart';
import 'package:enjaz7/models/stop.dart';

void main() {
  group('UltimateLocationNotificationService', () {
    late UltimateLocationNotificationService service;
    late List<Stop> testStops;

    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testStops = [
        Stop(name: 'Stop 1', lat: 30.0, lng: 31.0),
        Stop(name: 'Stop 2', lat: 30.1, lng: 31.1),
      ];
      service = UltimateLocationNotificationService(stops: testStops);
    });

    test('initialize should complete without error', () async {
      // Test that initialize doesn't throw
      await expectLater(service.initialize(), completes);
    });

    test('isMonitoring should be false initially', () {
      expect(service.isMonitoring, false);
    });

    test('refreshStops should update stops list', () async {
      final newStops = [Stop(name: 'New Stop', lat: 30.2, lng: 31.2)];
      await service.refreshStops(newStops);
      // Since stops is final in the class, but the list is mutable
      // Actually, in the code, stops.clear(); stops.addAll(newStops);
      // So it modifies the existing list
      expect(service.stops.length, 1);
      expect(service.stops.first.name, 'New Stop');
    });

    test('stopMonitoring should set isMonitoring to false', () {
      service.stopMonitoring();
      expect(service.isMonitoring, false);
    });
  });
}
