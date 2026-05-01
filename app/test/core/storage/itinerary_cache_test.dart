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

    test('saving creates a file in itineraries/', () async {
      final cache = FileItineraryCache(
        loadDocumentsDirectory: () async => tempDirectory,
      );
      final itinerary = _sampleItinerary();

      await cache.save(itinerary);

      final cacheDir = Directory('${tempDirectory.path}/itineraries');
      expect(cacheDir.existsSync(), isTrue);

      final files = cacheDir.listSync().whereType<File>().toList();
      expect(files.length, 1);
      expect(files.first.path, endsWith('_kyoto.json'));
    });

    test('list cached itineraries returning newest first', () async {
      final cache = FileItineraryCache(
        loadDocumentsDirectory: () async => tempDirectory,
      );

      final older = _sampleItinerary().copyWith(
        destination: 'Tokyo',
        generatedAt: '2026-04-18T12:00:00Z',
      );
      final newer = _sampleItinerary().copyWith(
        destination: 'Kyoto',
        generatedAt: '2026-04-19T12:00:00Z',
      );

      await cache.save(older);
      await cache.save(newer);

      final listed = await cache.listItineraries();
      expect(listed.length, 2);
      expect(listed.first.destination, 'Kyoto'); // newer
      expect(listed[1].destination, 'Tokyo'); // older
    });

    test('delete removes the file and updates list', () async {
      final cache = FileItineraryCache(
        loadDocumentsDirectory: () async => tempDirectory,
      );
      final itinerary = _sampleItinerary();

      await cache.save(itinerary);
      var listed = await cache.listItineraries();
      expect(listed.length, 1);

      await cache.deleteItinerary(listed.first.id);
      listed = await cache.listItineraries();
      expect(listed.isEmpty, isTrue);
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
