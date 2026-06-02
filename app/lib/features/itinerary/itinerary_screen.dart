import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/models/itinerary.dart';
import '../../core/theme/app_colors.dart';
import '../pdf/providers/pdf_export_provider.dart';
import '../pdf/share_service.dart';

import '../../core/theme/app_typography.dart';
import 'providers/itinerary_store_provider.dart';

import 'widgets/cost_summary_section.dart';
import 'widgets/day_header.dart';
import 'widgets/degradation_banner.dart';
import 'widgets/itinerary_map_tab.dart';
import 'widgets/venue_timeline_card.dart';

/// Placeholder screen for viewing a single itinerary.
class ItineraryScreen extends ConsumerStatefulWidget {
  const ItineraryScreen({
    super.key,
    required this.id,
    this.showMapTiles = true,
  });

  /// The itinerary identifier passed via the `:id` route parameter.
  final String id;
  final bool showMapTiles;

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen> {
  final ScrollController _timelineController = ScrollController();
  List<GlobalKey> _venueKeys = <GlobalKey>[];
  int? _selectedVenueIndex;

  @override
  void dispose() {
    _timelineController.dispose();
    super.dispose();
  }

  void _ensureVenueKeys(int count) {
    if (_venueKeys.length == count) {
      return;
    }
    _venueKeys = List<GlobalKey>.generate(count, (_) => GlobalKey());
  }

  void _handleVenueSelected(int index, {required bool isSplitView}) {
    if (index < 0 || index >= _venueKeys.length) {
      return;
    }

    setState(() {
      _selectedVenueIndex = index;
    });

    if (!isSplitView) {
      return;
    }

    final targetContext = _venueKeys[index].currentContext;
    if (targetContext == null) {
      return;
    }

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = ref.watch(
      itineraryStoreProvider.select((store) => store[widget.id]),
    );

    ref.listen<PdfExportState>(pdfExportControllerProvider, (previous, next) {
      if (previous?.status == next.status) {
        return;
      }

      if (next.status == PdfExportStatus.ready && next.filePath != null) {
        unawaited(
          _handlePdfShareAndSuccess(
            context,
            ref,
            filePath: next.filePath!,
            itinerary: itinerary,
          ),
        );
      }

      if (next.status == PdfExportStatus.error) {
        if (!context.mounted) {
          return;
        }
        _showExportErrorSnackbar(
          context,
          onRetry: () {
            ref
                .read(pdfExportControllerProvider.notifier)
                .export(itinerary: itinerary);
          },
        );
      }
    });

    final exportState = ref.watch(pdfExportControllerProvider);
    final isGenerating = exportState.status == PdfExportStatus.generating;
    final canPop = _canPop(context);

    if (itinerary == null) {
      final colorScheme = Theme.of(context).colorScheme;
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
                  FilledButton(
                    onPressed: () {
                      _popOrGoHome(context);
                    },
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final launcher = ref.read(sourceUrlLauncherProvider);
    final venueCount = itinerary.days.fold<int>(
      0,
      (total, day) => total + day.venues.length,
    );
    _ensureVenueKeys(venueCount);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSplitView = constraints.maxWidth >= 840;
        final horizontalPadding = constraints.maxWidth >= 600
            ? AppSpacing.xxl
            : AppSpacing.md;
        final timelinePadding = EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.md,
          horizontalPadding,
          AppSpacing.md,
        );

        final timeline = _TimelineTab(
          itinerary: itinerary,
          launcher: launcher,
          scrollController: _timelineController,
          venueKeys: _venueKeys,
          selectedVenueIndex: _selectedVenueIndex,
          onVenueSelected: (index) {
            _handleVenueSelected(index, isSplitView: isSplitView);
          },
          padding: timelinePadding,
        );

        final mapTab = ItineraryMapTab(
          itinerary: itinerary,
          showTiles: widget.showMapTiles,
          selectedVenueIndex: _selectedVenueIndex,
          onVenueSelected: (index) {
            _handleVenueSelected(index, isSplitView: isSplitView);
          },
        );

        final body = isSplitView
            ? Row(
                children: [
                  Expanded(child: timeline),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: mapTab),
                ],
              )
            : TabBarView(children: [timeline, mapTab]);

        final scaffold = Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                _popOrGoHome(context);
              },
            ),
            title: Text(itinerary.destination),
            bottom: isSplitView
                ? null
                : const TabBar(
                    tabs: [
                      Tab(text: 'Timeline'),
                      Tab(text: 'Map'),
                    ],
                  ),
          ),
          body: body,
          bottomNavigationBar: SafeArea(
            minimum: EdgeInsets.fromLTRB(
              horizontalPadding,
              AppSpacing.sm,
              horizontalPadding,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Semantics(
                    button: true,
                    label: 'Export itinerary as PDF',
                    child: FilledButton(
                      onPressed: isGenerating
                          ? null
                          : () {
                              ref
                                  .read(pdfExportControllerProvider.notifier)
                                  .export(itinerary: itinerary);
                            },
                      child: isGenerating
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: AppSpacing.sm),
                                Text('Exporting...'),
                              ],
                            )
                          : const Text('Export PDF'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop) {
              _navigateToHome(context);
            }
          },
          child: isSplitView
              ? scaffold
              : DefaultTabController(length: 2, child: scaffold),
        );
      },
    );
  }
}

class _TimelineTab extends StatelessWidget {
  const _TimelineTab({
    required this.itinerary,
    required this.launcher,
    required this.scrollController,
    required this.venueKeys,
    required this.selectedVenueIndex,
    required this.onVenueSelected,
    required this.padding,
  });

  final Itinerary itinerary;
  final SourceUrlLauncher launcher;
  final ScrollController scrollController;
  final List<GlobalKey> venueKeys;
  final int? selectedVenueIndex;
  final ValueChanged<int> onVenueSelected;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final showBanner = itinerary.isDegraded;
    final venueOffsets = _buildVenueOffsets(itinerary);
    // Extra item count: +1 for cost summary, +1 for banner (when degraded)
    final extraItems = showBanner ? 2 : 1;
    return ListView.builder(
      key: const ValueKey<String>('itinerary-timeline-list'),
      controller: scrollController,
      padding: padding,
      itemCount: itinerary.days.length + extraItems,
      itemBuilder: (context, index) {
        // Degradation banner is the very first item
        if (showBanner && index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: const DegradationBanner(),
          );
        }

        // Shift index to account for the optional banner
        final dayIndex = showBanner ? index - 1 : index;

        if (dayIndex == itinerary.days.length) {
          return CostSummarySection(costSummary: itinerary.costSummary);
        }

        final day = itinerary.days[dayIndex];
        final venueOffset = venueOffsets[dayIndex];
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
                Builder(
                  builder: (context) {
                    final globalIndex = venueOffset + venueIndex;
                    return KeyedSubtree(
                      key: venueKeys[globalIndex],
                      child: VenueTimelineCard(
                        key: ValueKey<String>(
                          '${day.dayNumber}-${day.venues[venueIndex].name}-$venueIndex',
                        ),
                        venue: day.venues[venueIndex],
                        index: globalIndex,
                        displayIndex: venueIndex,
                        isSelected: selectedVenueIndex == globalIndex,
                        onSelected: () => onVenueSelected(globalIndex),
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
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static List<int> _buildVenueOffsets(Itinerary itinerary) {
    final offsets = <int>[];
    var running = 0;
    for (final day in itinerary.days) {
      offsets.add(running);
      running += day.venues.length;
    }
    return offsets;
  }
}

Future<void> _handlePdfShareAndSuccess(
  BuildContext context,
  WidgetRef ref, {
  required String filePath,
  required Itinerary? itinerary,
}) async {
  try {
    await ref.read(pdfShareServiceProvider).sharePdf(filePath);
  } catch (e, stackTrace) {
    debugPrint('PDF Share failed: $e');
    debugPrint('Stack trace: $stackTrace');
    if (!context.mounted) {
      return;
    }
    _showExportErrorSnackbar(
      context,
      onRetry: () {
        ref
            .read(pdfExportControllerProvider.notifier)
            .export(itinerary: itinerary);
      },
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      backgroundColor: AppColors.surfaceLight,
      content: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.success),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'Itinerary exported!',
            style: AppTypography.body(color: AppColors.textPrimary),
          ),
        ],
      ),
    ),
  );
  ref.read(pdfExportControllerProvider.notifier).reset();
}

void _showExportErrorSnackbar(
  BuildContext context, {
  required VoidCallback onRetry,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: AppColors.error,
      content: const Text('Export failed. Please try again.'),
      action: SnackBarAction(label: 'Retry', onPressed: onRetry),
    ),
  );
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
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
}
