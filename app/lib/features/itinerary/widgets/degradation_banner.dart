import 'package:flutter/material.dart';

import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';

/// Banner displayed at the top of the itinerary timeline when the itinerary
/// was generated in degraded mode (Tavily verification service unavailable).
///
/// All venues in a degraded itinerary are AI-suggested and unverified.
class DegradationBanner extends StatelessWidget {
  /// Creates a [DegradationBanner].
  const DegradationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Warning: all venues are unverified AI suggestions',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.warning.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Live verification unavailable. '
                'All venues are AI-suggested and unverified.',
                style: AppTypography.bodySmall(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
