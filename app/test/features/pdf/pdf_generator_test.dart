import 'dart:io';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/features/pdf/pdf_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('generateItineraryPdf', () {
    late Directory tempDirectory;

    setUp(() {
      tempDirectory = Directory.systemTemp.createTempSync('nomad_pdf_test_');
    });

    tearDown(() {
      if (tempDirectory.existsSync()) {
        tempDirectory.deleteSync(recursive: true);
      }
    });

    test(
      'generates and writes a non-empty PDF for special characters',
      () async {
        final itinerary = _sampleItineraryWithSpecialCharacters();

        final result = await generateItineraryPdf(
          itinerary,
          loadDocumentsDirectory: () async => tempDirectory,
        );

        final file = File(result.filePath);
        expect(file.existsSync(), isTrue);
        expect(file.lengthSync(), greaterThan(0));
        expect(result.fileName, contains('_itinerary.pdf'));
      },
    );

    test('writes exported pdf into documents/exports folder', () async {
      final itinerary = _sampleItineraryWithSpecialCharacters();

      final result = await generateItineraryPdf(
        itinerary,
        loadDocumentsDirectory: () async => tempDirectory,
      );

      final file = File(result.filePath);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), greaterThan(0));
      expect(file.parent.path, endsWith('/exports'));
    });
  });
}

Itinerary _sampleItineraryWithSpecialCharacters() {
  return Itinerary(
    destination: 'Kyoto & Osaka',
    durationDays: 1,
    days: const [
      DayPlan(
        dayNumber: 1,
        date: '2026-04-05',
        estimatedDayCost: 120,
        venues: [
          Venue(
            name: 'Café L\'été ☕',
            address: '12 Sakura Street\nGion District',
            latitude: 35.0116,
            longitude: 135.7681,
            openingHours: ['Open daily 09:00-21:00'],
            rating: 4.6,
            estimatedCost: 45,
            isVerified: true,
          ),
          Venue(
            name: 'Temple Shrine – 東寺',
            address: '88 River Lane',
            latitude: 35.0212,
            longitude: 135.7797,
            openingHours: ['Closed on Mondays'],
            estimatedCost: 35,
            isVerified: false,
          ),
        ],
      ),
    ],
    costSummary: const CostSummary(
      food: 40,
      entertainment: 25,
      transport: 20,
      total: 120,
    ),
    generatedAt: '2026-04-23T12:00:00Z',
  );
}
