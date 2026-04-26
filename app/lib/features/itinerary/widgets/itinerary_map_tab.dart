import 'dart:async';
import 'dart:ui' as ui;

import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../providers/map_snapshot_provider.dart';
import 'map_venue_pin.dart';
import 'verification_badge.dart';
import 'venue_type_label.dart';

class ItineraryMapTab extends ConsumerStatefulWidget {
  const ItineraryMapTab({
    super.key,
    required this.itinerary,
    this.showTiles = true,
  });

  final Itinerary itinerary;
  final bool showTiles;

  @override
  ConsumerState<ItineraryMapTab> createState() => _ItineraryMapTabState();
}

class _ItineraryMapTabState extends ConsumerState<ItineraryMapTab> {
  static const int _pinStaggerStepMs = 100;
  static const int _pinMaxStaggerDelayMs = 1900;
  static const int _pinFadeInDurationMs = 260;
  static const int _routeRevealBufferMs = 120;
  static final Tween<double> _routeFadeTween = Tween<double>(begin: 0, end: 1);
  static const int _snapshotDelayMs = 1500;

  final MapController _mapController = MapController();
  final GlobalKey _mapBoundaryKey = GlobalKey();
  late List<_OrderedVenue> _orderedVenues;
  bool _hasFittedCamera = false;
  bool _showRoutes = false;
  bool _hasCapturedSnapshot = false;
  Timer? _routeRevealTimer;
  Timer? _snapshotTimer;

  @override
  void dispose() {
    _routeRevealTimer?.cancel();
    _snapshotTimer?.cancel();
    if (_mapController is ChangeNotifier) {
      (_mapController as ChangeNotifier).dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _orderedVenues = _flattenVenues(widget.itinerary);
    _scheduleRouteReveal();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fitCameraIfNeeded();
    });
  }

  @override
  void didUpdateWidget(covariant ItineraryMapTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itinerary != widget.itinerary) {
      _orderedVenues = _flattenVenues(widget.itinerary);
      _hasFittedCamera = false;
      _showRoutes = false;
      _scheduleRouteReveal();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _fitCameraIfNeeded();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final validPoints = _orderedVenues
        .where(
          (item) =>
              _isValidCoordinate(item.venue.latitude, item.venue.longitude),
        )
        .map((item) => LatLng(item.venue.latitude, item.venue.longitude))
        .toList(growable: false);
    final routePolylines = _showRoutes
        ? _buildRoutePolylines()
        : const <Polyline>[];

    return Stack(
      children: [
        RepaintBoundary(
          key: _mapBoundaryKey,
          child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: validPoints.isNotEmpty
                ? validPoints.first
                : const LatLng(20.0, 0.0),
            initialZoom: validPoints.isNotEmpty ? 12 : 2,
          ),
          children: [
            if (widget.showTiles)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'dev.nomadagent.app',
              ),
            if (_showRoutes && routePolylines.isNotEmpty)
              KeyedSubtree(
                key: const ValueKey<String>('map-route-layer'),
                child: TweenAnimationBuilder<double>(
                  tween: _routeFadeTween,
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  builder: (context, opacity, child) {
                    return Opacity(opacity: opacity, child: child);
                  },
                  child: IgnorePointer(
                    child: PolylineLayer(polylines: routePolylines),
                  ),
                ),
              ),
            MarkerLayer(
              markers: [
                for (final item in _orderedVenues)
                  if (_isValidCoordinate(
                    item.venue.latitude,
                    item.venue.longitude,
                  ))
                    Marker(
                      width: 40,
                      height: 40,
                      point: LatLng(item.venue.latitude, item.venue.longitude),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showVenueDetailSheet(item.venue),
                        child: MapVenuePin(
                          key: ValueKey<String>('map-pin-${item.order}'),
                          number: item.order,
                          isVerified: item.venue.isVerified,
                          index: item.order - 1,
                          venueType: item.venue.venueType,
                        ),
                      ),
                    ),
              ],
            ),
          ],
        ),
        ),
        if (validPoints.isEmpty)
          IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  'Map unavailable for this itinerary yet.',
                  style: AppTypography.body(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  void _fitCameraIfNeeded() {
    if (!mounted || _hasFittedCamera) {
      return;
    }

    final points = _orderedVenues
        .where(
          (item) =>
              _isValidCoordinate(item.venue.latitude, item.venue.longitude),
        )
        .map((item) => LatLng(item.venue.latitude, item.venue.longitude))
        .toList(growable: false);

    if (points.isEmpty) {
      _hasFittedCamera = true;
      return;
    }

    if (points.length == 1) {
      _mapController.move(points.first, 13);
      _hasFittedCamera = true;
      return;
    }

    final bounds = LatLngBounds.fromPoints(points);
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(AppSpacing.lg),
      ),
    );
    _hasFittedCamera = true;
    _scheduleSnapshotCapture();
  }

  void _scheduleRouteReveal() {
    _routeRevealTimer?.cancel();

    final validPinIndexes = _orderedVenues
        .where(
          (item) =>
              _isValidCoordinate(item.venue.latitude, item.venue.longitude),
        )
        .map((item) => item.order - 1)
        .toList(growable: false);

    if (validPinIndexes.length < 2) {
      return;
    }

    final maxIndex = validPinIndexes.reduce(
      (current, next) => current > next ? current : next,
    );
    final rawDelayMs = maxIndex <= 0 ? 0 : maxIndex * _pinStaggerStepMs;
    final clampedDelayMs = rawDelayMs > _pinMaxStaggerDelayMs
        ? _pinMaxStaggerDelayMs
        : rawDelayMs;
    final totalDelayMs =
        clampedDelayMs + _pinFadeInDurationMs + _routeRevealBufferMs;

    _routeRevealTimer = Timer(Duration(milliseconds: totalDelayMs), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _showRoutes = true;
      });
    });
  }

  void _scheduleSnapshotCapture() {
    if (_hasCapturedSnapshot) {
      return;
    }
    _snapshotTimer?.cancel();
    _snapshotTimer = Timer(
      const Duration(milliseconds: _snapshotDelayMs),
      _captureMapSnapshot,
    );
  }

  Future<void> _captureMapSnapshot() async {
    if (_hasCapturedSnapshot || !mounted) {
      return;
    }

    try {
      final boundary = _mapBoundaryKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null || !boundary.hasSize) {
        return;
      }

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null || !mounted) {
        return;
      }

      ref.read(mapSnapshotProvider.notifier).state =
          byteData.buffer.asUint8List();
      _hasCapturedSnapshot = true;
    } catch (_) {
      // Snapshot capture is best-effort; silently fall back to schematic.
    }
  }

  List<Polyline> _buildRoutePolylines() {
    final segments = <Polyline>[];

    for (var i = 0; i < _orderedVenues.length - 1; i++) {
      final start = _orderedVenues[i].venue;
      final end = _orderedVenues[i + 1].venue;
      final startValid = _isValidCoordinate(start.latitude, start.longitude);
      final endValid = _isValidCoordinate(end.latitude, end.longitude);

      if (!startValid || !endValid) {
        continue;
      }

      segments.add(
        Polyline(
          points: [
            LatLng(start.latitude, start.longitude),
            LatLng(end.latitude, end.longitude),
          ],
          strokeWidth: 4,
          color: AppColors.primaryVariant.withValues(alpha: 0.62),
          strokeCap: StrokeCap.round,
        ),
      );
    }

    return segments;
  }

  Future<void> _showVenueDetailSheet(Venue venue) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppSpacing.xl),
        ),
      ),
      builder: (context) => _VenueDetailSheet(venue: venue),
    );
  }

  static List<_OrderedVenue> _flattenVenues(Itinerary itinerary) {
    final ordered = <_OrderedVenue>[];
    var order = 1;

    for (final day in itinerary.days) {
      for (final venue in day.venues) {
        ordered.add(_OrderedVenue(order: order, venue: venue));
        order += 1;
      }
    }

    return ordered;
  }

  static bool _isValidCoordinate(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) {
      return false;
    }
    if (latitude == 0 && longitude == 0) {
      return false;
    }
    if (latitude < -90 || latitude > 90) {
      return false;
    }
    if (longitude < -180 || longitude > 180) {
      return false;
    }
    return true;
  }
}

class _OrderedVenue {
  const _OrderedVenue({required this.order, required this.venue});

  final int order;
  final Venue venue;
}

class _VenueDetailSheet extends StatelessWidget {
  const _VenueDetailSheet({required this.venue});

  final Venue venue;

  @override
  Widget build(BuildContext context) {
    final openingHoursLine = _openingHoursLine(venue.openingHours);
    final badgeType = _badgeTypeForVenue(venue);
    final ratingLine = venue.rating == null
        ? 'Rating unavailable'
        : '★ ${venue.rating!.toStringAsFixed(1)}';

    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              venue.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h3(color: colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              openingHoursLine,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodySmall(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              ratingLine,
              style: AppTypography.body(color: colorScheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (venue.venueType != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: VenueTypeLabel(
                  type: venue.venueType!,
                  color: colorScheme.onSurface,
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            VerificationBadge(type: badgeType, sourceUrl: venue.sourceUrl),
          ],
        ),
      ),
    );
  }

  static String _openingHoursLine(List<String>? openingHours) {
    if (openingHours == null || openingHours.isEmpty) {
      return 'Hours unavailable';
    }

    final nonEmptyLines = openingHours
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (nonEmptyLines.isEmpty) {
      return 'Hours unavailable';
    }
    return nonEmptyLines.join(' · ');
  }

  static VerificationBadgeType _badgeTypeForVenue(Venue venue) {
    if (venue.isVerified) {
      return VerificationBadgeType.verified;
    }

    final openingHours = venue.openingHours;
    final closedPattern = RegExp(r'\bclosed\b', caseSensitive: false);
    final hasClosedLabel =
        openingHours != null &&
        openingHours.any((line) => closedPattern.hasMatch(line));
    if (hasClosedLabel) {
      return VerificationBadgeType.closed;
    }

    return VerificationBadgeType.unverified;
  }
}
