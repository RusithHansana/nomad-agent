import 'package:app/core/models/cached_itinerary_summary.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget createWidgetUnderTest(List<CachedItinerarySummary> cacheResult) {
    return ProviderScope(
      overrides: [
        cachedItinerariesProvider.overrideWith(
          (ref) => Future.value(cacheResult),
        ),
      ],
      child: const MaterialApp(home: HistoryScreen()),
    );
  }

  testWidgets('Empty-state renders when cache returns empty list', (
    tester,
  ) async {
    await tester.pumpWidget(createWidgetUnderTest([]));

    // Wait for the FutureProvider to emit its data
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
    expect(
      find.text(
        'Your travel adventures start here. Type your first destination above!',
      ),
      findsOneWidget,
    );
    expect(find.text('Go to Home'), findsOneWidget);
  });

  testWidgets(
    'List renders the expected fields for at least one cached itinerary',
    (tester) async {
      final summaries = [
        CachedItinerarySummary(
          id: 'test_id.json',
          destination: 'Tokyo',
          durationDays: 3,
          generatedAt: '2026-04-27T16:00:00Z',
          venueCount: 12,
        ),
      ];

      await tester.pumpWidget(createWidgetUnderTest(summaries));
      await tester.pumpAndSettle();

      expect(find.text('Tokyo'), findsOneWidget);
      // Date formatting string will be present
      expect(find.text('3 days • Apr 27, 2026 • 12 venues'), findsOneWidget);
    },
  );

  // Swipe to delete would require overriding itineraryCacheProvider since it deletes via ref.read
}
