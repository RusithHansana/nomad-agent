import 'package:app/features/itinerary/widgets/verification_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unverified badge announces updated semantics label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: VerificationBadge(type: VerificationBadgeType.unverified),
        ),
      ),
    );

    final semantics = SemanticsTester(tester);

    expect(
      semantics,
      includesNodeWith(label: 'Unverified, recommend calling ahead'),
    );

    semantics.dispose();
  });
}
