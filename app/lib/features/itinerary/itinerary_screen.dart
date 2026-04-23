import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/itinerary.dart';

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
    final itinerary = ref.watch(
      itineraryStoreProvider.select((store) => store[id]),
    );

    if (itinerary == null) {
      final colorScheme = Theme.of(context).colorScheme;
      return PopScope(
        canPop: context.canPop(),
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            context.go('/');
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Itinerary'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
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
                    style: AppTypography.body(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  OutlinedButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go('/');
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

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          context.go('/');
        }
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/');
                }
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
    print(itinerary);
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
