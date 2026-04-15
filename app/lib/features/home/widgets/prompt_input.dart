import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Reusable prompt input field for the Home screen.
class PromptInput extends StatelessWidget {
  const PromptInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    super.key,
  });

  final TextEditingController controller;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: TextField(
        controller: controller,
        enabled: enabled,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(
          hintText: 'Where do you want to go?',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        ),
        style: AppTypography.body(color: theme.colorScheme.onSurface),
        onChanged: onChanged,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
