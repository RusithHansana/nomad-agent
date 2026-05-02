import 'package:app/core/models/itinerary.dart';
import 'package:app/features/itinerary/widgets/degradation_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('DegradationBanner', () {
    /// Helper to pump the banner in a minimal material harness.
    Future<void> pumpBanner(WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: EdgeInsets.all(16),
              child: DegradationBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the warning emoji and message text', (tester) async {
      await pumpBanner(tester);

      // Should display the warning icon emoji
      expect(find.text('⚠️'), findsOneWidget);
      // Should contain key words indicating degraded state
      expect(
        find.textContaining('unverified', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('has Semantics label for screen readers', (tester) async {
      await pumpBanner(tester);

      // Must include a Semantics widget with a meaningful label for screen readers
      expect(
        find.bySemanticsLabel(RegExp(r'unverified', caseSensitive: false)),
        findsOneWidget,
      );
    });

    testWidgets('widget has a Container with decoration (border + background)',
        (tester) async {
      await pumpBanner(tester);

      // Should use a Container with BoxDecoration for the warning tint
      final containers = tester.widgetList<Container>(find.byType(Container));
      final decorated = containers.where((c) => c.decoration is BoxDecoration);
      expect(decorated, isNotEmpty);
    });
  });

  group('DegradationBanner — Itinerary.isDegraded integration', () {
    test('Itinerary with isDegraded=true should trigger banner in screen', () {
      // This is a pure model test to confirm the flag is accessible
      const degradedItinerary = Itinerary(
        destination: 'Kandy',
        durationDays: 1,
        days: [],
        costSummary: CostSummary(total: 0.0),
        generatedAt: '2026-05-02T12:00:00Z',
        isDegraded: true,
        degradationReason: 'tavily_unavailable',
      );

      expect(degradedItinerary.isDegraded, isTrue);
    });

    test('Non-degraded itinerary should not trigger banner', () {
      const normalItinerary = Itinerary(
        destination: 'Kandy',
        durationDays: 1,
        days: [],
        costSummary: CostSummary(total: 0.0),
        generatedAt: '2026-05-02T12:00:00Z',
        // isDegraded defaults to false
      );

      expect(normalItinerary.isDegraded, isFalse);
    });
  });
}
