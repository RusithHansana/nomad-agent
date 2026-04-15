import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/app.dart';

void main() {
  group('Home prompt input flow', () {
    testWidgets('Go button is disabled when prompt is empty', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      final finder = find.widgetWithText(ElevatedButton, 'Go');
      expect(finder, findsOneWidget);

      final button = tester.widget<ElevatedButton>(finder);
      expect(button.onPressed, isNull);
    });

    testWidgets('Tapping suggestion chip fills text field and enables Go', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      const suggestion = 'Weekend in Tokyo, vintage gaming and ramen';
      await tester.tap(find.text(suggestion));
      await tester.pump();

      expect(find.text(suggestion), findsWidgets);

      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Go'),
      );
      expect(button.onPressed, isNotNull);
    });

    testWidgets('Tapping Go navigates to generate and shows prompt', (
      tester,
    ) async {
      await tester.pumpWidget(const ProviderScope(child: App()));

      const prompt = '3 days in Lisbon, local food and fado';
      await tester.enterText(find.byType(TextField), prompt);
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Go'));
      await tester.pumpAndSettle();

      expect(find.text('Generating…'), findsOneWidget);
      expect(find.textContaining(prompt), findsOneWidget);
    });
  });
}
