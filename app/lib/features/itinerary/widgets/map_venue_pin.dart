import 'dart:async';

import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

class MapVenuePin extends StatefulWidget {
  const MapVenuePin({
    super.key,
    required this.number,
    required this.isVerified,
    required this.index,
    this.venueType,
  });

  final int number;
  final bool isVerified;
  final int index;
  final String? venueType;

  @override
  State<MapVenuePin> createState() => _MapVenuePinState();
}

class _MapVenuePinState extends State<MapVenuePin> {
  static const int _staggerStepMs = 100;
  static const int _maxStaggerDelayMs = 1900;

  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final rawDelayMs = widget.index <= 0 ? 0 : widget.index * _staggerStepMs;
    final safeDelayMs = rawDelayMs > _maxStaggerDelayMs
        ? _maxStaggerDelayMs
        : rawDelayMs;

    _timer = Timer(Duration(milliseconds: safeDelayMs), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = true;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinColor = widget.isVerified
        ? AppColors.secondary
        : AppColors.warning;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        offset: _visible ? Offset.zero : const Offset(0, -0.2),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.onSecondary, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.13),
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: _buildPinContent(),
        ),
      ),
    );
  }

  Widget _buildPinContent() {
    final type = widget.venueType?.toLowerCase() ?? '';
    IconData? icon;

    if (type == 'restaurant') {
      icon = Icons.restaurant;
    } else if (type == 'nature') {
      icon = Icons.park;
    } else if (type == 'event') {
      icon = Icons.event;
    } else if (type == 'tour') {
      icon = Icons.directions_bus;
    } else if (type == 'attraction') {
      icon = Icons.local_see;
    }

    if (icon != null) {
      return Icon(
        icon,
        size: 16,
        color: AppColors.onSecondary,
      );
    }

    return Text(
      '${widget.number}',
      style: AppTypography.bodySmall(
        color: AppColors.onSecondary,
      ).copyWith(fontWeight: FontWeight.w700),
    );
  }
}
