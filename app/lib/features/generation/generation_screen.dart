import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/constants/app_spacing.dart';
import 'providers/generation_provider.dart';
import 'providers/onboarding_overlay_provider.dart';
import 'widgets/cold_start_overlay.dart';
import 'widgets/onboarding_overlay.dart';
import 'widgets/thought_log_viewer.dart';

/// Live generation screen with streaming thought-log viewer.
class GenerationScreen extends ConsumerStatefulWidget {
  const GenerationScreen({required this.prompt, super.key});

  final String prompt;

  @override
  ConsumerState<GenerationScreen> createState() => _GenerationScreenState();
}

class _GenerationScreenState extends ConsumerState<GenerationScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) {
      return;
    }
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrompt = widget.prompt.trim().isNotEmpty;
    final generationState = ref.watch(
      generationControllerProvider(widget.prompt),
    );
    final shouldShowOnboarding = hasPrompt
        ? ref.watch(onboardingOverlayControllerProvider).valueOrNull ?? false
        : false;

    ref.listen(generationControllerProvider(widget.prompt), (previous, next) {
      final previousLength = previous?.entries.length ?? 0;
      if (next.entries.length > previousLength) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          _scrollToBottom();
        });
      }

      final completedNow =
          previous?.phase != GenerationPhase.complete &&
          next.phase == GenerationPhase.complete;
      if (completedNow && next.itineraryId != null && context.mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          context.go(AppRoutes.itineraryDetail(next.itineraryId!));
        });
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Generating…')),
      body: hasPrompt
          ? Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Stack(
                children: [
                  ThoughtLogViewer(
                    destination: generationState.destinationDisplay,
                    elapsedSeconds: generationState.elapsedSeconds,
                    entries: generationState.entries,
                    scrollController: _scrollController,
                    isError: generationState.phase == GenerationPhase.error,
                    errorMessage: generationState.errorMessage,
                    onRetry: () {
                      ref
                          .read(
                            generationControllerProvider(
                              widget.prompt,
                            ).notifier,
                          )
                          .retry();
                    },
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: generationState.showColdStartOverlay
                        ? const ColdStartOverlay(key: ValueKey('cold-start'))
                        : const SizedBox.shrink(key: ValueKey('no-overlay')),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: shouldShowOnboarding
                        ? OnboardingOverlay(
                            key: const ValueKey('onboarding-layer'),
                            onDismiss: () {
                              ref
                                  .read(
                                    onboardingOverlayControllerProvider
                                        .notifier,
                                  )
                                  .dismiss();
                            },
                          )
                        : const SizedBox.shrink(key: ValueKey('no-onboarding')),
                  ),
                ],
              ),
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'No prompt received yet. Start from Home to generate your trip.',
                  maxLines: 6,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
    );
  }
}
