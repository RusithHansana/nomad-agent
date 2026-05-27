import 'package:app/features/itinerary/widgets/map_venue_pin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reduced motion skips entrance animations', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          home: Scaffold(
            body: MapVenuePin(number: 1, isVerified: true, index: 0),
          ),
        ),
      ),
    );

    expect(find.byType(AnimatedOpacity), findsNothing);
    expect(find.byType(AnimatedSlide), findsNothing);
  });
}
