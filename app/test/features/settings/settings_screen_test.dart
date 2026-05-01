import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/settings/settings_screen.dart';
import 'package:app/features/settings/providers/theme_provider.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/cached_itinerary_summary.dart';

class MockItineraryCache implements ItineraryCache {
  bool clearAllCalled = false;

  @override
  Future<void> clearAll() async {
    clearAllCalled = true;
  }

  @override
  Future<bool> deleteItinerary(String id) async => true;

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
  group('SettingsScreen', () {
    testWidgets('renders dark mode toggle, about section, and clear history', (tester) async {
      final mockCache = MockItineraryCache();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itineraryCacheProvider.overrideWithValue(mockCache),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      // Verify Dark Mode toggle
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('Toggle between light and dark themes'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      // Verify About section
      expect(find.text('App version'), findsOneWidget);
      expect(find.text('0.1.0'), findsOneWidget);

      // Verify Clear History section
      expect(find.text('Clear History'), findsOneWidget);
      expect(find.text('Delete all saved itineraries'), findsOneWidget);
    });

    testWidgets('toggling dark mode updates provider', (tester) async {
      final mockCache = MockItineraryCache();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itineraryCacheProvider.overrideWithValue(mockCache),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      final switchTile = find.byType(SwitchListTile);
      expect(tester.widget<SwitchListTile>(switchTile).value, false);

      await tester.tap(switchTile);
      await tester.pumpAndSettle();

      // We cannot easily verify the exact provider state directly here without reading it,
      // but tapping it should change the UI state to true.
      expect(tester.widget<SwitchListTile>(switchTile).value, true);
    });

    testWidgets('clear history cancel does not delete', (tester) async {
      final mockCache = MockItineraryCache();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itineraryCacheProvider.overrideWithValue(mockCache),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Clear History'));
      await tester.pumpAndSettle();

      expect(find.text('Clear History?'), findsOneWidget);
      
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Clear History?'), findsNothing);
      expect(mockCache.clearAllCalled, false);
    });

    testWidgets('clear history confirm calls clearAll', (tester) async {
      final mockCache = MockItineraryCache();
      
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            itineraryCacheProvider.overrideWithValue(mockCache),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Clear History'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete All'));
      await tester.pumpAndSettle();

      expect(mockCache.clearAllCalled, true);
      expect(find.text('History cleared'), findsOneWidget); // SnackBar
    });
  });
}
