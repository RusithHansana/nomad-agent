import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'widgets/prompt_input.dart';
import 'widgets/suggestion_chips.dart';

/// Home screen prompt entry for starting itinerary generation.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isSubmitting = false;

  bool get _canSubmit =>
      _promptController.text.trim().isNotEmpty && !_isSubmitting;

  void _handleSuggestionTap(String suggestion) {
    if (_isSubmitting) {
      return;
    }

    _promptController.text = suggestion;
    _promptController.selection = TextSelection.collapsed(
      offset: suggestion.length,
    );
    setState(() {});
  }

  void _handleSubmit() {
    if (!_canSubmit) {
      return;
    }

    final prompt = _promptController.text.trim();
    setState(() {
      _isSubmitting = true;
    });

    Future.microtask(() {
      if (!mounted) {
        return;
      }

      try {
        context.go(AppRoutes.generate, extra: prompt);
      } catch (_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _isSubmitting = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Describe your dream trip in a sentence. NomadAgent handles the rest.',
                style: AppTypography.bodySmall(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PromptInput(
                controller: _promptController,
                enabled: !_isSubmitting,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _handleSubmit(),
              ),
              const SizedBox(height: AppSpacing.md),
              SuggestionChips(onSuggestionSelected: _handleSuggestionTap),
              const SizedBox(height: AppSpacing.xl),
              ElevatedButton(
                onPressed: _canSubmit ? _handleSubmit : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  disabledBackgroundColor: AppColors.secondary.withValues(
                    alpha: 0.3,
                  ),
                  foregroundColor: AppColors.onSecondary,
                  disabledForegroundColor: AppColors.onSecondary.withValues(
                    alpha: 0.3,
                  ),
                  minimumSize: const Size.fromHeight(52),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Go'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
