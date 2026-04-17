import 'dart:async';

import 'package:app/core/models/sse_event.dart';
import 'package:app/features/generation/generation_screen.dart';
import 'package:app/features/generation/providers/generation_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('GenerationScreen', () {
    testWidgets('shows cold start overlay after 3 seconds without events', (
      tester,
    ) async {
      const prompt = 'Trip in Tokyo';
      final streamController = StreamController<SSEEvent>();

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) {
                if (requestedPrompt != prompt) {
                  return const Stream<SSEEvent>.empty();
                }
                return streamController.stream;
              };
            }),
          ],
        ),
      );

      expect(
        find.text(
          'NomadAgent is warming up — your research begins in a moment.',
        ),
        findsNothing,
      );

      await tester.pump(const Duration(seconds: 3));

      expect(
        find.text(
          'NomadAgent is warming up — your research begins in a moment.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('hides cold start overlay when first event arrives', (
      tester,
    ) async {
      const prompt = 'Trip in Lisbon';
      final streamController = StreamController<SSEEvent>();

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) {
                if (requestedPrompt != prompt) {
                  return const Stream<SSEEvent>.empty();
                }
                return streamController.stream;
              };
            }),
          ],
        ),
      );

      await tester.pump(const Duration(seconds: 3));
      expect(find.byKey(const ValueKey('cold-start')), findsOneWidget);

      streamController.add(
        const ThoughtLogEvent(
          timestamp: '2026-04-17T00:00:00Z',
          message: 'Starting research...',
          icon: '🔍',
          step: 'start',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('cold-start')), findsNothing);
    });

    testWidgets('renders thought log entry icon and message', (tester) async {
      const prompt = 'Trip in Kyoto';
      final streamController = StreamController<SSEEvent>();

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) {
                if (requestedPrompt != prompt) {
                  return const Stream<SSEEvent>.empty();
                }
                return streamController.stream;
              };
            }),
          ],
        ),
      );

      streamController.add(
        const ThoughtLogEvent(
          timestamp: '2026-04-17T00:00:00Z',
          message: 'Scanning neighborhoods',
          icon: '🔍',
          step: 'search',
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 180));

      expect(find.text('🔍'), findsOneWidget);
      expect(find.text('Scanning neighborhoods'), findsOneWidget);
    });

    testWidgets('shows Try Again when stream fails after one reconnect', (
      tester,
    ) async {
      const prompt = 'Trip in Seoul';
      var calls = 0;

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) {
                if (requestedPrompt != prompt) {
                  return const Stream<SSEEvent>.empty();
                }
                calls += 1;
                if (calls == 1) {
                  return const Stream<SSEEvent>.empty();
                }
                return Stream<SSEEvent>.error(Exception('disconnect'));
              };
            }),
          ],
        ),
      );

      await tester.pump();
      await tester.pump();

      expect(find.widgetWithText(ElevatedButton, 'Try Again'), findsOneWidget);
    });
  });
}

Widget _buildHarness({
  required String prompt,
  required List<Override> overrides,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(home: GenerationScreen(prompt: prompt)),
  );
}
