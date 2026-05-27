import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/features/itinerary/widgets/itinerary_map_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('map pins expose semantic labels with venue details', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      final itinerary = Itinerary(
        destination: 'Kyoto',
        durationDays: 1,
        generatedAt: '2026-05-27T10:00:00Z',
        costSummary: const CostSummary(total: 0),
        days: [
          DayPlan(
            dayNumber: 1,
            venues: const [
              Venue(
                name: 'Tea House',
                address: '12 Sakura Street',
                latitude: 35.0,
                longitude: 135.0,
                openingHours: ['Open daily 09:00-21:00'],
                isVerified: true,
              ),
            ],
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ItineraryMapTab(itinerary: itinerary, showTiles: false),
          ),
        ),
      );

      await tester.pump();

      final label =
          'Venue 1: Tea House, verified, opens Open daily 09:00-21:00';
      final semanticsFinder = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties?.label == label,
      );
      expect(semanticsFinder, findsOneWidget);
    } finally {
      semanticsHandle.dispose();
    }
  });
}
