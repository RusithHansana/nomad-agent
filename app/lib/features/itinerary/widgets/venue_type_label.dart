import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';

class VenueTypeLabel extends StatelessWidget {
  const VenueTypeLabel({
    super.key,
    required this.type,
    required this.color,
  });

  final String type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toLowerCase().trim();
    IconData? icon;
    String label = type;

    if (normalized == 'restaurant') {
      icon = Icons.restaurant;
      label = 'Restaurant';
    } else if (normalized == 'nature') {
      icon = Icons.park;
      label = 'Nature';
    } else if (normalized == 'event') {
      icon = Icons.event;
      label = 'Event';
    } else if (normalized == 'tour') {
      icon = Icons.directions_bus;
      label = 'Tour';
    } else if (normalized == 'attraction') {
      icon = Icons.local_see;
      label = 'Attraction';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: AppTypography.bodySmall(color: color),
        ),
      ],
    );
  }
}
