import 'dart:async';

import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

import 'verification_badge.dart';

class VenueTimelineCard extends StatefulWidget {
  const VenueTimelineCard({
    super.key,
    required this.venue,
    required this.index,
    required this.onViewSource,
  });

  final Venue venue;
  final int index;
  final Future<void> Function(Venue venue) onViewSource;

  @override
  State<VenueTimelineCard> createState() => _VenueTimelineCardState();
}

class _VenueTimelineCardState extends State<VenueTimelineCard> {
  bool _visible = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(milliseconds: widget.index * 50), () {
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
    final colorScheme = Theme.of(context).colorScheme;
    final textPrimary = colorScheme.onSurface;
    final textSecondary = colorScheme.onSurfaceVariant;
    final primaryColor = colorScheme.primary;
    final openingHoursText = _openingHoursText(widget.venue.openingHours);
    final statusText = _openingStatus(openingHoursText);
    final badgeType = _badgeType(widget.venue);
    final verificationNote = widget.venue.verificationNote?.trim();
    final hasVerificationNote =
        verificationNote != null && verificationNote.isNotEmpty;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
      opacity: _visible ? 1 : 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        offset: _visible ? Offset.zero : const Offset(0, 0.08),
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _timeLabel(widget.venue, widget.index),
                      style: AppTypography.caption(
                        color: textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        Container(
                          width: AppSpacing.xs,
                          height: AppSpacing.xs,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Container(
                            height: 1,
                            color: primaryColor.withValues(alpha: 0.25),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (badgeType == VerificationBadgeType.verified)
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xxs,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                widget.venue.name,
                                style: AppTypography.h3(
                                  color: textPrimary,
                                ),
                              ),
                              VerificationBadge(
                                type: VerificationBadgeType.verified,
                                sourceUrl: widget.venue.sourceUrl,
                              ),
                            ],
                          )
                        else ...[
                          Text(
                            widget.venue.name,
                            style: AppTypography.h3(
                              color: textPrimary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          VerificationBadge(
                            type: badgeType,
                            sourceUrl: widget.venue.sourceUrl,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          widget.venue.address,
                          style: AppTypography.bodySmall(
                            color: textSecondary,
                          ),
                        ),
                        if (badgeType != VerificationBadgeType.verified &&
                            hasVerificationNote)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xxs),
                            child: Text(
                              verificationNote,
                              style: AppTypography.bodySmall(
                                color: AppColors.warning,
                              ),
                            ),
                          ),
                        if (openingHoursText != null) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            openingHoursText,
                            style: AppTypography.bodySmall(
                              color: textSecondary,
                            ),
                          ),
                          if (statusText != null)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.xxs,
                              ),
                              child: Text(
                                statusText,
                                style: AppTypography.bodySmall(
                                  color: statusText == 'Open now'
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                            ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.xs,
                          children: [
                            if (widget.venue.rating != null)
                              Text(
                                '★ ${widget.venue.rating!.toStringAsFixed(1)}',
                                style: AppTypography.bodySmall(
                                  color: textPrimary,
                                ),
                              ),
                            if (_costText(widget.venue) != null)
                              Text(
                                _costText(widget.venue)!,
                                style: AppTypography.bodySmall(
                                  color: textPrimary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        InkWell(
                          onTap: () => widget.onViewSource(widget.venue),
                          child: Text(
                            'View source →',
                            style: AppTypography.bodySmall(
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _timeLabel(Venue venue, int index) {
    final timeSlot = venue.timeSlot;
    if (timeSlot != null && timeSlot.trim().isNotEmpty) {
      return timeSlot.trim();
    }

    switch (index) {
      case 0:
        return 'Morning';
      case 1:
        return 'Midday';
      case 2:
        return 'Afternoon';
      case 3:
        return 'Evening';
      default:
        return 'Stop ${index + 1}';
    }
  }

  static String? _openingHoursText(List<String>? openingHours) {
    if (openingHours == null || openingHours.isEmpty) {
      return null;
    }

    final clean = openingHours
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (clean.isEmpty) {
      return null;
    }

    return clean.join(' • ');
  }

  static String? _openingStatus(String? openingHoursText) {
    if (openingHoursText == null || openingHoursText.isEmpty) {
      return null;
    }

    final normalized = openingHoursText.toLowerCase();
    if (normalized.contains('closed')) {
      return 'Closed';
    }
    return 'Open now';
  }

  static String? _costText(Venue venue) {
    final level = venue.priceLevel;
    if (level != null && level > 0) {
      return List<String>.filled(level, '\$').join();
    }

    final estimate = venue.estimatedCost;
    if (estimate == null) {
      return null;
    }

    final rounded = estimate.round();
    if (estimate == rounded.toDouble()) {
      return '~\$$rounded';
    }
    return '~\$${estimate.toStringAsFixed(1)}';
  }

  static VerificationBadgeType _badgeType(Venue venue) {
    if (_isPermanentlyClosed(venue)) {
      return VerificationBadgeType.closed;
    }
    return venue.isVerified
        ? VerificationBadgeType.verified
        : VerificationBadgeType.unverified;
  }

  static bool _isPermanentlyClosed(Venue venue) {
    final inOpeningHours =
        venue.openingHours?.any((line) => _containsPermanentlyClosed(line)) ??
        false;
    final inVerificationNote = _containsPermanentlyClosed(
      venue.verificationNote,
    );
    return inOpeningHours || inVerificationNote;
  }

  static bool _containsPermanentlyClosed(String? text) {
    final normalized = text?.toLowerCase().trim();
    if (normalized == null || normalized.isEmpty) {
      return false;
    }
    return normalized.contains('permanently closed');
  }
}
