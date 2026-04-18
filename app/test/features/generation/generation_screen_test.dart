import 'dart:async';

import 'package:app/core/models/sse_event.dart';
import 'package:app/core/storage/onboarding_flag_store.dart';
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
      addTearDown(streamController.close);

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
      addTearDown(streamController.close);

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
      addTearDown(streamController.close);

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

    testWidgets('shows onboarding overlay for first-time users', (
      tester,
    ) async {
      const prompt = 'Trip in Colombo';
      final fakeStore = _InMemoryOnboardingFlagStore(initialSeen: false);

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            onboardingFlagStoreProvider.overrideWithValue(fakeStore),
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) =>
                  const Stream<SSEEvent>.empty();
            }),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('onboarding-overlay')), findsOneWidget);
      expect(
        find.text(
          'NomadAgent researches in real time. Watch the Thought Log to see every step.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('dismisses onboarding overlay on tap', (tester) async {
      const prompt = 'Trip in Berlin';
      final fakeStore = _InMemoryOnboardingFlagStore(initialSeen: false);

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            onboardingFlagStoreProvider.overrideWithValue(fakeStore),
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) =>
                  const Stream<SSEEvent>.empty();
            }),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('onboarding-overlay')), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('onboarding-dismiss-surface')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('onboarding-overlay')), findsNothing);
      expect(fakeStore.hasSeen, isTrue);
    });

    testWidgets('dismisses onboarding overlay with Got it button', (
      tester,
    ) async {
      const prompt = 'Trip in Osaka';
      final fakeStore = _InMemoryOnboardingFlagStore(initialSeen: false);

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            onboardingFlagStoreProvider.overrideWithValue(fakeStore),
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) =>
                  const Stream<SSEEvent>.empty();
            }),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('onboarding-overlay')), findsNothing);
      expect(fakeStore.hasSeen, isTrue);
    });

    testWidgets('does not show onboarding after dismissal on next visit', (
      tester,
    ) async {
      const prompt = 'Trip in Madrid';
      final fakeStore = _InMemoryOnboardingFlagStore(initialSeen: false);

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            onboardingFlagStoreProvider.overrideWithValue(fakeStore),
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) =>
                  const Stream<SSEEvent>.empty();
            }),
          ],
        ),
      );
      await tester.pump();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Got it'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.pumpWidget(
        _buildHarness(
          prompt: prompt,
          overrides: [
            onboardingFlagStoreProvider.overrideWithValue(fakeStore),
            generationStreamFactoryProvider.overrideWith((ref) {
              return (requestedPrompt, cancelToken) =>
                  const Stream<SSEEvent>.empty();
            }),
          ],
        ),
      );
      await tester.pump();

      expect(find.byKey(const ValueKey('onboarding-overlay')), findsNothing);
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

class _InMemoryOnboardingFlagStore implements OnboardingFlagStore {
  _InMemoryOnboardingFlagStore({required bool initialSeen})
    : _hasSeen = initialSeen;

  bool _hasSeen;

  bool get hasSeen => _hasSeen;

  @override
  Future<bool> getHasSeenThoughtLogOnboarding() async {
    return _hasSeen;
  }

  @override
  Future<void> setHasSeenThoughtLogOnboarding() async {
    _hasSeen = true;
  }
}
