import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'providers/itinerary_store_provider.dart';
import 'widgets/cost_summary_section.dart';
import 'widgets/day_header.dart';
import 'widgets/venue_timeline_card.dart';

/// Placeholder screen for viewing a single itinerary.
class ItineraryScreen extends ConsumerWidget {
  const ItineraryScreen({super.key, required this.id});

  /// The itinerary identifier passed via the `:id` route parameter.
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itinerary = ref.watch(
      itineraryStoreProvider.select((store) => store[id]),
    );

    if (itinerary == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Itinerary')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Itinerary not found.',
                  style: AppTypography.h3(color: AppColors.textPrimary),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Please return and generate a new trip.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(color: AppColors.textSecondary),
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
      );
    }

    final launcher = ref.read(sourceUrlLauncherProvider);

    return Scaffold(
      appBar: AppBar(title: Text(itinerary.destination)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          for (var dayIndex = 0; dayIndex < itinerary.days.length; dayIndex++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DayHeader(dayPlan: itinerary.days[dayIndex]),
                  const SizedBox(height: AppSpacing.md),
                  for (
                    var venueIndex = 0;
                    venueIndex < itinerary.days[dayIndex].venues.length;
                    venueIndex++
                  )
                    VenueTimelineCard(
                      venue: itinerary.days[dayIndex].venues[venueIndex],
                      index: venueIndex,
                      onViewSource: (venue) async {
                        final sourceUrl = venue.sourceUrl;
                        if (sourceUrl == null || sourceUrl.trim().isEmpty) {
                          return;
                        }

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
                      },
                    ),
                ],
              ),
            ),
          CostSummarySection(costSummary: itinerary.costSummary),
        ],
      ),
    );
  }
}
