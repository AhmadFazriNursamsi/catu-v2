import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:catu_mobile/core/constants/app_constants.dart';
import 'package:catu_mobile/core/models/models.dart';

void main() {
  group('AppConstants Tests', () {
    test('constants have expected values', () {
      expect(AppConstants.appName, 'CATU Pelayanan');
      expect(AppConstants.primaryBlue, const Color(0xFF1E3A8A));
      expect(AppConstants.accentGold, const Color(0xFFD97706));
    });
  });

  group('formatServiceDate Helper Tests', () {
    test('formats valid ISO date correctly', () {
      final formatted = formatServiceDate('2026-09-14');
      expect(formatted, 'Senin, 14/09/26');
    });

    test('handles date with time string correctly', () {
      final formatted = formatServiceDate('2026-09-14T08:30:00.000Z');
      expect(formatted, 'Senin, 14/09/26');
    });

    test('handles null and empty input gracefully', () {
      expect(formatServiceDate(null), '-');
      expect(formatServiceDate(''), '-');
    });

    test('handles invalid date string by returning raw string', () {
      expect(formatServiceDate('not-a-date'), 'not-a-date');
    });
  });

  group('ServiceCategory Model Tests', () {
    test('deserializes from JSON correctly', () {
      final json = {
        'id': 1,
        'name': 'Misa Kudus',
        'description': 'Pelayanan Misa Arwah / Lingkungan',
        'isUrgentByDefault': false,
      };

      final category = ServiceCategory.fromJson(json);
      expect(category.id, 1);
      expect(category.name, 'Misa Kudus');
      expect(category.description, 'Pelayanan Misa Arwah / Lingkungan');
      expect(category.isUrgentByDefault, false);
    });

    test('handles default fallback values in JSON', () {
      final json = {
        'id': 2,
        'name': 'Minyak Suci',
      };

      final category = ServiceCategory.fromJson(json);
      expect(category.id, 2);
      expect(category.name, 'Minyak Suci');
      expect(category.description, '');
      expect(category.isUrgentByDefault, false);
    });
  });

  group('OrderItem Model Tests', () {
    test('deserializes and serializes OrderItem correctly', () {
      final json = {
        'id': 101,
        'itemName': 'Pemberkatan Rumah',
        'scheduledDate': '2026-09-15',
        'scheduledTimeStart': '10:00',
        'scheduledTimeEnd': '11:30',
        'locationName': 'Jl. Mawar No. 12',
        'status': 'PENDING',
      };

      final item = OrderItem.fromJson(json);
      expect(item.id, 101);
      expect(item.itemName, 'Pemberkatan Rumah');
      expect(item.scheduledDate, '2026-09-15');
      expect(item.status, 'PENDING');
      expect(item.acceptedRomoName, isNull);
    });
  });

  group('Widget Rendering Smoke Test', () {
    testWidgets('Basic themed widget renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppConstants.primaryBlue,
              primary: AppConstants.primaryBlue,
            ),
          ),
          home: const Scaffold(
            body: Center(
              child: Text('CATU Pelayanan Active'),
            ),
          ),
        ),
      );

      expect(find.text('CATU Pelayanan Active'), findsOneWidget);
    });
  });
}
