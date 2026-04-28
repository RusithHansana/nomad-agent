import 'package:app/core/models/cached_itinerary_summary.dart';
import 'package:app/core/router/app_router.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:app/features/itinerary/providers/itinerary_store_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cachedAsync = ref.watch(cachedItinerariesProvider);

    return Scaffold(
      appBar: AppBar(title: Text('History')),
      body: cachedAsync.when(
        data: (itineraries) {
          if (itineraries.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildList(context, ref, itineraries);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, ref, error),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your travel adventures start here. Type your first destination above!',
              textAlign: TextAlign.center,
              style: AppTypography.body(),
            ),
            const SizedBox(height: AppSpacing.lg),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.home),
              child: Text('Go to Home'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Failed to load itineraries.', style: AppTypography.body()),
          const SizedBox(height: AppSpacing.sm),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(cachedItinerariesProvider);
            },
            child: Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<CachedItinerarySummary> itineraries,
  ) {
    return ListView.separated(
      itemCount: itineraries.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final summary = itineraries[index];
        return _buildListItem(context, ref, summary);
      },
    );
  }

  Widget _buildListItem(
    BuildContext context,
    WidgetRef ref,
    CachedItinerarySummary summary,
  ) {
    DateTime? date = DateTime.tryParse(summary.generatedAt);
    final dateString = date != null
        ? DateFormat('MMM d, yyyy').format(date)
        : summary.generatedAt;

    final daysStr = summary.durationDays == 1
        ? '1 day'
        : '${summary.durationDays} days';

    return Dismissible(
      key: Key(summary.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: Icon(Icons.delete, color: Theme.of(context).colorScheme.onError),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Delete itinerary?'),
            content: Text(
              'Are you sure you want to delete your trip to ${summary.destination}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (direction) async {
        await ref.read(itineraryCacheProvider).deleteItinerary(summary.id);
        ref.invalidate(cachedItinerariesProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Itinerary deleted.')));
        }
      },
      child: ListTile(
        title: Text(summary.destination, style: AppTypography.h3()),
        subtitle: Text('$daysStr • $dateString • ${summary.venueCount} venues'),
        onTap: () => _handleItemTap(context, ref, summary),
      ),
    );
  }

  Future<void> _handleItemTap(
    BuildContext context,
    WidgetRef ref,
    CachedItinerarySummary summary,
  ) async {
    final cache = ref.read(itineraryCacheProvider);
    final itinerary = await cache.loadItinerary(summary.id);

    if (itinerary != null && context.mounted) {
      ref.read(itineraryStoreProvider.notifier).upsert(itinerary);
      context.go(AppRoutes.itineraryDetail(itinerary.generatedAt));
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load itinerary.')),
      );
    }
  }
}
