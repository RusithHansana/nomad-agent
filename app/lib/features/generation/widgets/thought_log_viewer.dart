import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../providers/generation_provider.dart';
import 'thought_log_entry.dart' as entry_widget;

class ThoughtLogViewer extends StatelessWidget {
  const ThoughtLogViewer({
    required this.destination,
    required this.elapsedSeconds,
    required this.entries,
    required this.scrollController,
    required this.isError,
    required this.errorMessage,
    required this.onRetry,
    super.key,
  });

  final String destination;
  final int elapsedSeconds;
  final List<ThoughtLogEntry> entries;
  final ScrollController scrollController;
  final bool isError;
  final String? errorMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.thoughtLogBackgroundDark
        : AppColors.thoughtLogBackgroundLight;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '🔍 Researching your trip to $destination...',
                style: AppTypography.h3(color: textColor),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _formatElapsed(elapsedSeconds),
              style: AppTypography.bodySmall(color: textColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final item = entries[index];
                      return entry_widget.ThoughtLogEntry(
                        key: ValueKey(item.id),
                        icon: item.icon,
                        message: item.message,
                      );
                    },
                  ),
                ),
                if (isError) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      errorMessage ??
                          'Connection lost while generating your itinerary. Please try again.',
                      style: AppTypography.bodySmall(color: AppColors.error),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton(
                      onPressed: onRetry,
                      child: const Text('Try Again'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatElapsed(int elapsedSeconds) {
    final minutes = elapsedSeconds ~/ 60;
    final seconds = elapsedSeconds % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    return '$mm:$ss';
  }
}
