import 'dart:io';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FileItineraryCache', () {
    late Directory tempDirectory;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync('nomad_cache_test_');
    });

    tearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test('saves and loads latest itinerary from local storage', () async {
      final cache = FileItineraryCache(
        loadDocumentsDirectory: () async => tempDirectory,
      );
      final itinerary = _sampleItinerary();

      await cache.save(itinerary);
      final loaded = await cache.loadLatest();

      expect(loaded, isNotNull);
      expect(loaded?.generatedAt, itinerary.generatedAt);
      expect(loaded?.destination, itinerary.destination);
    });

    test('returns null when no cached itinerary exists', () async {
      final cache = FileItineraryCache(
        loadDocumentsDirectory: () async => tempDirectory,
      );

      final loaded = await cache.loadLatest();

      expect(loaded, isNull);
    });
  });
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
