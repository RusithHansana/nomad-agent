import 'dart:async';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/cached_itinerary_summary.dart';
import 'package:app/core/models/sse_event.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/features/generation/providers/generation_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GenerationController', () {
    test('persists completed itinerary into local cache', () async {
      final streamController = StreamController<SSEEvent>();
      final cache = _InMemoryItineraryCache();

      final container = ProviderContainer(
        overrides: [
          generationStreamFactoryProvider.overrideWith((ref) {
            return (requestedPrompt, cancelToken) {
              return streamController.stream;
            };
          }),
          itineraryCacheProvider.overrideWithValue(cache),
        ],
      );

      addTearDown(streamController.close);
      addTearDown(container.dispose);

      const prompt = 'Trip to Kyoto';
      container.read(generationControllerProvider(prompt));

      final itinerary = _sampleItinerary();
      streamController.add(
        ItineraryCompleteEvent(
          timestamp: '2026-04-24T10:00:00Z',
          itinerary: itinerary,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cache.latest?.generatedAt, itinerary.generatedAt);
      expect(cache.latest?.destination, itinerary.destination);
    });
  });
}

class _InMemoryItineraryCache implements ItineraryCache {
  Itinerary? latest;

  @override
  Future<Itinerary?> loadLatest() async {
    return latest;
  }

  @override
  Future<void> save(Itinerary itinerary) async {
    latest = itinerary;
  }

  @override
  Future<bool> deleteItinerary(String id) async => false;

  @override
  Future<List<CachedItinerarySummary>> listItineraries() async => [];

  @override
  Future<Itinerary?> loadItinerary(String id) async => null;
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
