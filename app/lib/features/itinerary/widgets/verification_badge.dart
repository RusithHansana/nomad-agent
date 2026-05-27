import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/accessibility/reduced_motion.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

enum VerificationBadgeType { verified, unverified, closed }

class VerificationBadge extends StatefulWidget {
  const VerificationBadge({super.key, required this.type, this.sourceUrl});

  final VerificationBadgeType type;
  final String? sourceUrl;

  @override
  State<VerificationBadge> createState() => _VerificationBadgeState();
}

class _VerificationBadgeState extends State<VerificationBadge>
    with SingleTickerProviderStateMixin {
  final GlobalKey<TooltipState> _tooltipKey = GlobalKey<TooltipState>();
  late final AnimationController _controller;
  late Animation<double> _scale;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1,
    );
    _scale = const AlwaysStoppedAnimation<double>(1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = ReducedMotion.isEnabled(context);
    _configureAnimation();
  }

  @override
  void didUpdateWidget(covariant VerificationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.type != widget.type) {
      _configureAnimation();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = _styleFor(widget.type);
    final sourceUrl = widget.sourceUrl?.trim();
    final canShowSource =
        widget.type == VerificationBadgeType.verified &&
        sourceUrl != null &&
        sourceUrl.isNotEmpty;

    final badge = Semantics(
      label: theme.semanticLabel,
      hint: canShowSource ? 'Tap to show source URL' : null,
      button: canShowSource,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSpacing.xl),
          onTap: canShowSource
              ? () => _tooltipKey.currentState?.ensureTooltipVisible()
              : null,
          child: ScaleTransition(
            scale: _scale,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.foreground.withValues(
                  alpha: theme.backgroundAlpha,
                ),
                borderRadius: BorderRadius.circular(AppSpacing.xl),
                border: Border.all(color: theme.foreground),
              ),
              child: Text(
                theme.label,
                style: AppTypography.caption(color: theme.foreground),
              ),
            ),
          ),
        ),
      ),
    );

    if (!canShowSource) {
      return badge;
    }

    return Tooltip(
      key: _tooltipKey,
      triggerMode: TooltipTriggerMode.manual,
      message: sourceUrl,
      child: badge,
    );
  }

  void _configureAnimation() {
    final shouldAnimate =
        widget.type == VerificationBadgeType.verified && !_reduceMotion;

    if (!shouldAnimate) {
      if (_controller.isAnimating) {
        _controller.stop();
      }
      _controller.value = 1;
      _scale = const AlwaysStoppedAnimation<double>(1);
      return;
    }

    _scale = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 0,
          end: 1.1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 65,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(
          begin: 1.1,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
    ]).animate(_controller);
    _controller.value = 0;
    _controller.forward();
  }

  static _BadgeStyle _styleFor(VerificationBadgeType type) {
    switch (type) {
      case VerificationBadgeType.verified:
        return const _BadgeStyle(
          label: '✅ Verified',
          semanticLabel: 'Verified',
          foreground: AppColors.success,
          backgroundAlpha: 0.12,
        );
      case VerificationBadgeType.unverified:
        return const _BadgeStyle(
          label: '⚠️ Unverified',
          semanticLabel: 'Unverified, recommend calling ahead',
          foreground: AppColors.warning,
          backgroundAlpha: 0.14,
        );
      case VerificationBadgeType.closed:
        return const _BadgeStyle(
          label: '❌ Closed',
          semanticLabel: 'Closed',
          foreground: AppColors.error,
          backgroundAlpha: 0.12,
        );
    }
  }
}

class _BadgeStyle {
  const _BadgeStyle({
    required this.label,
    required this.semanticLabel,
    required this.foreground,
    required this.backgroundAlpha,
  });

  final String label;
  final String semanticLabel;
  final Color foreground;
  final double backgroundAlpha;
}
