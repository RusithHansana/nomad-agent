import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/itinerary.dart';

import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

class CostSummarySection extends StatelessWidget {
  const CostSummarySection({super.key, required this.costSummary});

  final CostSummary costSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foodDisplay = _formatOptionalCost(costSummary.food);
    final entertainmentDisplay = _formatOptionalCost(costSummary.entertainment);
    final transportDisplay = _formatOptionalCost(costSummary.transport);
    final hasUnknownCategory =
        foodDisplay.isUnknown ||
        entertainmentDisplay.isUnknown ||
        transportDisplay.isUnknown;

    return Card(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cost Summary',
              style: AppTypography.h3(color: colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            _CostSummaryRow(label: 'Food', value: foodDisplay.value),
            _CostSummaryRow(
              label: 'Entertainment',
              value: entertainmentDisplay.value,
            ),
            _CostSummaryRow(label: 'Transport', value: transportDisplay.value),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Divider(height: 1),
            ),
            _CostSummaryRow(
              label: 'Trip Total',
              value: _formatCost(costSummary.total),
              emphasize: true,
            ),
            if (hasUnknownCategory)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'ⓘ Some category totals are currently unavailable.',
                  style: AppTypography.caption(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static _CostDisplay _formatOptionalCost(double? amount) {
    if (amount == null || !amount.isFinite) {
      return const _CostDisplay(value: '—', isUnknown: true);
    }
    return _CostDisplay(value: _formatCost(amount), isUnknown: false);
  }

  static String _formatCost(double amount) {
    if (!amount.isFinite) {
      return '—';
    }

    final rounded = amount.roundToDouble();
    if ((amount - rounded).abs() < 1e-9) {
      return '~\$${rounded.toInt()}';
    }
    return '~\$${amount.toStringAsFixed(1)}';
  }
}

class _CostDisplay {
  const _CostDisplay({required this.value, required this.isUnknown});

  final String value;
  final bool isUnknown;
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
    final colorScheme = Theme.of(context).colorScheme;
    final style = emphasize
        ? AppTypography.body(color: colorScheme.onSurface)
        : AppTypography.bodySmall(color: colorScheme.onSurfaceVariant);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: emphasize
                  ? AppTypography.body(color: colorScheme.onSurface)
                  : AppTypography.bodySmall(color: colorScheme.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}
