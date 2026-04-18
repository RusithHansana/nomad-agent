import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import 'thought_log_entry.dart' as entry_widget;

class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({required this.onDismiss, super.key});

  final VoidCallback onDismiss;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  static const _previewLines = <({String icon, String message})>[
    (icon: '🧭', message: 'Breaking into 3 tasks...'),
    (icon: '🔍', message: 'Searching neighborhoods...'),
    (icon: '✅', message: 'Verified: walkable central district'),
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final overlayColor = Theme.of(
      context,
    ).scaffoldBackgroundColor.withValues(alpha: 0.94);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark
        ? AppColors.thoughtLogBackgroundDark
        : AppColors.thoughtLogBackgroundLight;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return GestureDetector(
      key: const ValueKey('onboarding-dismiss-surface'),
      behavior: HitTestBehavior.opaque,
      onTap: widget.onDismiss,
      child: ColoredBox(
        color: overlayColor,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                key: const ValueKey('onboarding-overlay'),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'NomadAgent researches in real time. Watch the Thought Log to see every step.',
                      style: AppTypography.body(color: textColor),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    _StreamingPreview(controller: _controller),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: Semantics(
                        label: 'Dismiss onboarding overlay',
                        button: true,
                        child: ElevatedButton(
                          onPressed: widget.onDismiss,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                          ),
                          child: const Text('Got it'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreamingPreview extends StatelessWidget {
  const _StreamingPreview({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? AppColors.darkTextSecondary.withValues(alpha: 0.35)
        : AppColors.textSecondary.withValues(alpha: 0.35);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final progress = controller.value;
        final index = math.min(2, (progress * 3).floor());
        final visibleCount = index + 1;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              for (final line in _OnboardingOverlayState._previewLines.take(
                visibleCount,
              ))
                entry_widget.ThoughtLogEntry(
                  icon: line.icon,
                  message: line.message,
                ),
            ],
          ),
        );
      },
    );
  }
}
