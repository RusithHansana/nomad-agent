import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';

/// Suggestion chips for quick prompt entry on the Home screen.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({required this.onSuggestionSelected, super.key});

  final ValueChanged<String> onSuggestionSelected;

  static const List<String> suggestions = [
    'Weekend in Tokyo, vintage gaming and ramen',
    '3 days in Lisbon, local food and fado',
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: suggestions
          .map(
            (suggestion) => ActionChip(
              label: Text(suggestion),
              onPressed: () => onSuggestionSelected(suggestion),
            ),
          )
          .toList(growable: false),
    );
  }
}
