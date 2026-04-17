import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ColdStartOverlay extends StatefulWidget {
  const ColdStartOverlay({super.key});

  @override
  State<ColdStartOverlay> createState() => _ColdStartOverlayState();
}

class _ColdStartOverlayState extends State<ColdStartOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.95),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  final scale =
                      1 + (math.sin(_controller.value * math.pi * 2) * 0.06);
                  return Transform.scale(scale: scale, child: child);
                },
                child: const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primaryVariant,
                  foregroundColor: AppColors.surface,
                  child: Icon(Icons.explore, size: 28),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'NomadAgent is warming up — your research begins in a moment.',
                textAlign: TextAlign.center,
                style: AppTypography.body(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
