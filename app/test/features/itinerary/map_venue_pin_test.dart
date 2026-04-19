import 'package:app/core/theme/app_colors.dart';
import 'package:app/features/itinerary/widgets/map_venue_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MapVenuePin', () {
    testWidgets('verified pin uses terracotta and shows number', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapVenuePin(number: 3, isVerified: true, index: 0),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget);

      final containerFinder = find.ancestor(
        of: find.text('3'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, AppColors.secondary);
    });

    testWidgets('unverified pin uses warning color and shows number', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MapVenuePin(number: 7, isVerified: false, index: 0),
          ),
        ),
      );

      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('7'), findsOneWidget);

      final containerFinder = find.ancestor(
        of: find.text('7'),
        matching: find.byType(Container),
      );
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, AppColors.warning);
    });
  });
}
