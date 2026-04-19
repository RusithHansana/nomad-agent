import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/features/itinerary/itinerary_screen.dart';
import 'package:app/features/itinerary/providers/itinerary_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('ItineraryScreen', () {
    testWidgets('renders day headers with stop count and estimated cost', (
      tester,
    ) async {
      final itinerary = _sampleItinerary();

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Day 1 — Sunday, April 5'), findsOneWidget);
      expect(find.text('2 stops'), findsOneWidget);
      expect(find.text('~\$85'), findsOneWidget);
    });

    testWidgets('shows Timeline and Map tabs and renders map pins', (
      tester,
    ) async {
      final itinerary = _sampleItinerary();

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Timeline'), findsOneWidget);
      expect(find.text('Map'), findsOneWidget);

      await tester.tap(find.text('Map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 850));

      expect(find.byKey(const ValueKey<String>('map-pin-1')), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('map-pin-2')), findsOneWidget);
      expect(find.byType(TileLayer), findsNothing);
    });

    testWidgets('renders venue card details, badges, notes and source link', (
      tester,
    ) async {
      final itinerary = _sampleItinerary();

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tea House'), findsOneWidget);
      expect(find.text('12 Sakura Street'), findsOneWidget);
      expect(find.text('★ 4.6'), findsOneWidget);
      expect(find.text('✅ Verified'), findsOneWidget);
      expect(find.text('⚠️ Unverified'), findsOneWidget);
      expect(
        find.text('Limited online signal, verify opening hours.'),
        findsOneWidget,
      );
      expect(find.text('View source →'), findsWidgets);
    });

    testWidgets('renders cost summary with category totals and trip total', (
      tester,
    ) async {
      final itinerary = _sampleItinerary();

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Cost Summary'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('itinerary-timeline-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cost Summary'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Trip Total'), findsOneWidget);
      expect(find.text('~\$40'), findsOneWidget);
      expect(find.text('~\$25'), findsOneWidget);
      expect(find.text('~\$20'), findsOneWidget);
      expect(find.text('~\$85'), findsAtLeastNWidgets(1));
    });

    testWidgets('shows unknown category totals with friendly helper text', (
      tester,
    ) async {
      final itinerary = _sampleItinerary().copyWith(
        costSummary: const CostSummary(total: 85),
      );

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Cost Summary'),
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey<String>('itinerary-timeline-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cost Summary'), findsOneWidget);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Entertainment'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Trip Total'), findsOneWidget);
      expect(find.text('~\$85'), findsAtLeastNWidgets(1));
      expect(find.text('—'), findsNWidgets(3));
      expect(
        find.text('ⓘ Some category totals are currently unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets('uses timeSlot first and fallback label for missing timeSlot', (
      tester,
    ) async {
      final itinerary = _sampleItinerary();

      await tester.pumpWidget(
        _buildHarness(
          id: itinerary.generatedAt,
          overrides: [
            itineraryStoreProvider.overrideWith(
              () => _FakeItineraryStoreNotifier(<String, Itinerary>{
                itinerary.generatedAt: itinerary,
              }),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('09:00 AM'), findsOneWidget);
      expect(find.text('Midday'), findsOneWidget);
    });
  });
}

Widget _buildHarness({
  required String id,
  required List<Override> overrides,
  bool showMapTiles = false,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      home: ItineraryScreen(id: id, showMapTiles: showMapTiles),
    ),
  );
}

class _FakeItineraryStoreNotifier extends ItineraryStoreNotifier {
  _FakeItineraryStoreNotifier(this._initialState);

  final Map<String, Itinerary> _initialState;

  @override
  Map<String, Itinerary> build() {
    return _initialState;
  }
}

Itinerary _sampleItinerary() {
  return Itinerary(
    destination: 'Kyoto',
    durationDays: 1,
    days: const [
      DayPlan(
        dayNumber: 1,
        date: '2026-04-05',
        estimatedDayCost: 85,
        venues: [
          Venue(
            name: 'Tea House',
            address: '12 Sakura Street',
            latitude: 35.0116,
            longitude: 135.7681,
            openingHours: ['Open daily 09:00-21:00'],
            rating: 4.6,
            priceLevel: 2,
            sourceUrl: 'https://example.com/tea-house',
            timeSlot: '09:00 AM',
            isVerified: true,
          ),
          Venue(
            name: 'Temple Garden',
            address: '88 River Lane',
            latitude: 35.0212,
            longitude: 135.7797,
            openingHours: ['Closed on Mondays'],
            estimatedCost: 30,
            sourceUrl: 'https://example.com/temple-garden',
            isVerified: false,
            verificationNote: 'Limited online signal, verify opening hours.',
          ),
        ],
      ),
    ],
    costSummary: const CostSummary(
      food: 40,
      entertainment: 25,
      transport: 20,
      total: 85,
    ),
    generatedAt: '2026-04-19T12:00:00Z',
  );
}
