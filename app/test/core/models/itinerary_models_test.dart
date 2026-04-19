import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/sse_event.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('Itinerary JSON models', () {
    test('fromJson/toJson round-trip keeps snake_case contract', () {
      final fixture = <String, Object?>{
        'destination': 'Tokyo',
        'duration_days': 1,
        'days': <Map<String, Object?>>[
          <String, Object?>{
            'day_number': 1,
            'date': '2026-04-14',
            'venues': <Map<String, Object?>>[
              <String, Object?>{
                'name': 'Senso-ji',
                'address': '2 Chome-3-1 Asakusa, Taito City, Tokyo',
                'latitude': 35.7148,
                'longitude': 139.7967,
                'time_slot': '09:00 AM',
                'rating': 4.6,
                'is_verified': false,
                'verification_note': 'Source unavailable',
              },
            ],
          },
        ],
        'cost_summary': <String, Object?>{'entertainment': 20.0, 'total': 20.0},
        'generated_at': '2026-04-14T10:00:00Z',
      };

      final itinerary = Itinerary.fromJson(fixture);
      final roundTrip = itinerary.toJson();

      expect(roundTrip['duration_days'], 1);
      expect(roundTrip['generated_at'], '2026-04-14T10:00:00Z');
      expect(roundTrip.containsKey('durationDays'), isFalse);

      final days = roundTrip['days'] as List<Object?>;
      final firstDay = days.first as Map<String, Object?>;
      final venues = firstDay['venues'] as List<Object?>;
      final firstVenue = venues.first as Map<String, Object?>;
      expect(firstVenue['is_verified'], isFalse);
      expect(firstVenue['time_slot'], '09:00 AM');
      expect(firstVenue.containsKey('source_url'), isFalse);
    });
  });

  group('SSE union parser', () {
    test('parses itinerary_complete payload into ItineraryCompleteEvent', () {
      final eventJson = <String, Object?>{
        'event_type': 'itinerary_complete',
        'timestamp': '2026-04-14T10:00:01Z',
        'data': <String, Object?>{
          'itinerary': <String, Object?>{
            'destination': 'Tokyo',
            'duration_days': 1,
            'days': <Map<String, Object?>>[
              <String, Object?>{
                'day_number': 1,
                'venues': <Map<String, Object?>>[
                  <String, Object?>{
                    'name': 'Senso-ji',
                    'address': '2 Chome-3-1 Asakusa, Taito City, Tokyo',
                    'latitude': 35.7148,
                    'longitude': 139.7967,
                    'is_verified': true,
                  },
                ],
              },
            ],
            'cost_summary': <String, Object?>{'total': 42.0},
            'generated_at': '2026-04-14T10:00:00Z',
          },
        },
      };

      final event = SSEEvent.fromJson(eventJson);

      expect(event, isA<ItineraryCompleteEvent>());
      final itineraryEvent = event as ItineraryCompleteEvent;
      expect(itineraryEvent.itinerary.destination, 'Tokyo');
      expect(itineraryEvent.itinerary.durationDays, 1);
      expect(itineraryEvent.toJson()['event_type'], 'itinerary_complete');
    });
  });
}
