import 'package:flutter/material.dart';

import '../../../core/constants/app_spacing.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

class ThoughtLogEntry extends StatefulWidget {
  const ThoughtLogEntry({required this.icon, required this.message, super.key});

  final String icon;
  final String message;

  @override
  State<ThoughtLogEntry> createState() => _ThoughtLogEntryState();
}

class _ThoughtLogEntryState extends State<ThoughtLogEntry> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark
        ? AppColors.darkTextPrimary
        : AppColors.textPrimary;

    return AnimatedSlide(
      offset: _visible ? Offset.zero : const Offset(-0.08, 0),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.icon,
                style: AppTypography.thoughtLog(color: textColor),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  widget.message,
                  style: AppTypography.thoughtLog(color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
