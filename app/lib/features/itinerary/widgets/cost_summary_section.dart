import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/itinerary.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

class CostSummarySection extends StatelessWidget {
  const CostSummarySection({super.key, required this.costSummary});

  final CostSummary costSummary;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Summary',
              style: AppTypography.h3(color: AppColors.textPrimary),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (costSummary.food != null)
              _CostSummaryRow(
                label: 'Food',
                value: _formatCost(costSummary.food!),
              ),
            if (costSummary.entertainment != null)
              _CostSummaryRow(
                label: 'Entertainment',
                value: _formatCost(costSummary.entertainment!),
              ),
            if (costSummary.transport != null)
              _CostSummaryRow(
                label: 'Transport',
                value: _formatCost(costSummary.transport!),
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Divider(height: 1),
            ),
            _CostSummaryRow(
              label: 'Trip Total',
              value: _formatCost(costSummary.total),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCost(double amount) {
    final rounded = amount.round();
    if (amount == rounded.toDouble()) {
      return '~\$$rounded';
    }
    return '~\$${amount.toStringAsFixed(1)}';
  }
}

class _CostSummaryRow extends StatelessWidget {
  const _CostSummaryRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? AppTypography.body(color: AppColors.textPrimary)
        : AppTypography.bodySmall(color: AppColors.textSecondary);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            value,
            style: emphasize
                ? AppTypography.body(color: AppColors.textPrimary)
                : AppTypography.bodySmall(color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
