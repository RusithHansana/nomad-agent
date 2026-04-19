import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/itinerary.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DayHeader extends StatelessWidget {
  const DayHeader({super.key, required this.dayPlan});

  final DayPlan dayPlan;

  @override
  Widget build(BuildContext context) {
    final stops = dayPlan.venues.length;
    final estimatedCost = dayPlan.estimatedDayCost;

    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dayLabel(dayPlan),
                style: AppTypography.h2(color: AppColors.textPrimary),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Text(
                    '$stops stops',
                    style: AppTypography.bodySmall(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (estimatedCost != null)
                    Text(
                      _formatDayCost(estimatedCost),
                      style: AppTypography.bodySmall(
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _dayLabel(DayPlan dayPlan) {
    final dateRaw = dayPlan.date;
    if (dateRaw == null || dateRaw.isEmpty) {
      return 'Day ${dayPlan.dayNumber}';
    }

    final parsed = DateTime.tryParse(dateRaw);
    if (parsed == null) {
      return 'Day ${dayPlan.dayNumber}';
    }

    final formatted = DateFormat('EEEE, MMMM d').format(parsed);
    return 'Day ${dayPlan.dayNumber} — $formatted';
  }

  static String _formatDayCost(double cost) {
    final rounded = cost.round();
    if (cost == rounded.toDouble()) {
      return '~\$$rounded';
    }
    return '~\$${cost.toStringAsFixed(1)}';
  }
}
