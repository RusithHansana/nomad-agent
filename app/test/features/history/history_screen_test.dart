import 'package:app/core/models/cached_itinerary_summary.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/features/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/models/itinerary.dart';

class _FakeItineraryCache implements ItineraryCache {
  bool deleteCalled = false;
  String? deletedId;

  @override
  Future<bool> deleteItinerary(String id) async {
    deleteCalled = true;
    deletedId = id;
    return true;
  }

  @override
  Future<List<CachedItinerarySummary>> listItineraries() async => [];
  @override
  Future<Itinerary?> loadItinerary(String id) async => null;
  @override
  Future<Itinerary?> loadLatest() async => null;
  @override
  Future<void> save(Itinerary itinerary) async {}
}

void main() {
  Widget createWidgetUnderTest(
    List<CachedItinerarySummary> cacheResult, [
    ItineraryCache? cache,
  ]) {
    return ProviderScope(
      overrides: [
        cachedItinerariesProvider.overrideWith(
          (ref) => Future.value(cacheResult),
        ),
        if (cache != null) itineraryCacheProvider.overrideWithValue(cache),
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
  testWidgets('Swipe to delete shows confirmation and deletes on confirm', (
    tester,
  ) async {
    final summaries = [
      CachedItinerarySummary(
        id: 'test_id.json',
        destination: 'Tokyo',
        durationDays: 3,
        generatedAt: '2026-04-27T16:00:00Z',
        venueCount: 12,
      ),
    ];
    final fakeCache = _FakeItineraryCache();

    await tester.pumpWidget(createWidgetUnderTest(summaries, fakeCache));
    await tester.pumpAndSettle();

    expect(find.text('Tokyo'), findsOneWidget);

    // Swipe to dismiss
    await tester.drag(find.text('Tokyo'), const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // Dialog should appear
    expect(find.text('Delete itinerary?'), findsOneWidget);

    // Tap cancel first to ensure it's not deleted
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(fakeCache.deleteCalled, isFalse);
    expect(find.text('Tokyo'), findsOneWidget); // Still there

    // Swipe again to dismiss
    await tester.drag(find.text('Tokyo'), const Offset(-500.0, 0.0));
    await tester.pumpAndSettle();

    // Tap Delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(fakeCache.deleteCalled, isTrue);
    expect(fakeCache.deletedId, 'test_id.json');
  });
}
