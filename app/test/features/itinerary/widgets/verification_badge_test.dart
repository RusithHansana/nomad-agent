import 'package:app/features/itinerary/widgets/verification_badge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('unverified badge announces updated semantics label', (
    tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();
    try {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: VerificationBadge(type: VerificationBadgeType.unverified),
          ),
        ),
      );

      await tester.pump();
      final semantics = tester.getSemantics(find.byType(VerificationBadge));
      expect(
        semantics.label,
        startsWith('Unverified, recommend calling ahead'),
      );
    } finally {
      semanticsHandle.dispose();
    }
  });
}
