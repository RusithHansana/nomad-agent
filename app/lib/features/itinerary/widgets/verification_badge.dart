import 'package:app/core/constants/app_spacing.dart';
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
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    final shouldAnimate = widget.type == VerificationBadgeType.verified;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: shouldAnimate ? 0 : 1,
    );
    if (shouldAnimate) {
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
      _controller.forward();
      return;
    }

    _scale = const AlwaysStoppedAnimation<double>(1);
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
          semanticLabel: 'Unverified',
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
