import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/itinerary.dart';
import '../pdf/providers/pdf_export_provider.dart';

import '../../core/theme/app_typography.dart';
import 'providers/itinerary_store_provider.dart';
import 'widgets/cost_summary_section.dart';
import 'widgets/day_header.dart';
import 'widgets/itinerary_map_tab.dart';
import 'widgets/venue_timeline_card.dart';

/// Placeholder screen for viewing a single itinerary.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({
    super.key,
    required this.id,
    this.showMapTiles = true,
  });

  /// The itinerary identifier passed via the `:id` route parameter.
  final String id;
  final bool showMapTiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<PdfExportState>(pdfExportControllerProvider, (previous, next) {
      if (previous?.status == next.status) {
        return;
      }

      if (next.status == PdfExportStatus.ready && next.filePath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF saved to ${next.filePath}')),
        );
        ref.read(pdfExportControllerProvider.notifier).reset();
      }

      if (next.status == PdfExportStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage ??
                  'Unable to export PDF right now. Please try again.',
            ),
          ),
        );
      }
    });

    final itinerary = ref.watch(
      itineraryStoreProvider.select((store) => store[id]),
    );

    if (itinerary == null) {
      final colorScheme = Theme.of(context).colorScheme;
      final canPop = _canPop(context);
      return PopScope(
        canPop: canPop,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _navigateToHome(context);
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Itinerary'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _popOrGoHome(context);
              },
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Itinerary not found.',
                    style: AppTypography.h3(color: colorScheme.onSurface),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Please return and generate a new trip.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () {
                      _popOrGoHome(context);
                    },
                    child: const Text('Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final launcher = ref.read(sourceUrlLauncherProvider);
    final exportState = ref.watch(pdfExportControllerProvider);
    final isGenerating = exportState.status == PdfExportStatus.generating;
    final canPop = _canPop(context);

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateToHome(context);
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _popOrGoHome(context);
              },
            ),
            title: Text(itinerary.destination),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Timeline'),
                Tab(text: 'Map'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _TimelineTab(itinerary: itinerary, launcher: launcher),
              ItineraryMapTab(itinerary: itinerary, showTiles: showMapTiles),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Semantics(
              button: true,
              label: 'Export itinerary as PDF',
              child: FilledButton(
                onPressed: isGenerating
                    ? null
                    : () {
                        ref
                            .read(pdfExportControllerProvider.notifier)
                            .export(itinerary);
                      },
                child: isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Text('Exporting...'),
                        ],
                      )
                    : const Text('Export PDF'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({required this.itinerary, required this.launcher});

  final Itinerary itinerary;
  final SourceUrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const ValueKey<String>('itinerary-timeline-list'),
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: itinerary.days.length + 1,
      itemBuilder: (context, dayIndex) {
        if (dayIndex == itinerary.days.length) {
          return CostSummarySection(costSummary: itinerary.costSummary);
        }

        final day = itinerary.days[dayIndex];
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DayHeader(dayPlan: day),
              const SizedBox(height: AppSpacing.md),
              for (
                var venueIndex = 0;
                venueIndex < day.venues.length;
                venueIndex++
              )
                VenueTimelineCard(
                  key: ValueKey<String>(
                    '${day.dayNumber}-${day.venues[venueIndex].name}-$venueIndex',
                  ),
                  venue: day.venues[venueIndex],
                  index: venueIndex,
                  onViewSource: (venue) async {
                    final sourceUrl = venue.sourceUrl;
                    if (sourceUrl == null || sourceUrl.trim().isEmpty) {
                      return;
                    }

                    try {
                      final launched = await launcher(sourceUrl);
                      if (!launched && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unable to open source link right now.',
                            ),
                          ),
                        );
                      }
                    } catch (_) {
                      if (!context.mounted) {
                        return;
                      }
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Unable to open source link right now.',
                          ),
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

bool _canPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    return router.canPop();
  }
  return Navigator.of(context).canPop();
}

void _popOrGoHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/');
    }
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

void _navigateToHome(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    router.go('/');
  }
}
