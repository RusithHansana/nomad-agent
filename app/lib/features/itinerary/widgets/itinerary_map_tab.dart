import 'package:app/core/constants/app_spacing.dart';
import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:app/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_venue_pin.dart';

class ItineraryMapTab extends StatefulWidget {
  const ItineraryMapTab({
    super.key,
    required this.itinerary,
    this.showTiles = true,
  });

  final Itinerary itinerary;
  final bool showTiles;

  @override
  State<ItineraryMapTab> createState() => _ItineraryMapTabState();
}

class _ItineraryMapTabState extends State<ItineraryMapTab> {
  final MapController _mapController = MapController();
  late List<_OrderedVenue> _orderedVenues;
  bool _hasFittedCamera = false;

  @override
  void dispose() {
    if (_mapController is ChangeNotifier) {
      (_mapController as ChangeNotifier).dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _orderedVenues = _flattenVenues(widget.itinerary);
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

    return Stack(
      children: [
        FlutterMap(
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
                      child: MapVenuePin(
                        key: ValueKey<String>('map-pin-${item.order}'),
                        number: item.order,
                        isVerified: item.venue.isVerified,
                        index: item.order - 1,
                      ),
                    ),
              ],
            ),
          ],
        ),
        if (validPoints.isEmpty)
          IgnorePointer(
            child: Center(
              child: Container(
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: Text(
                  'Map unavailable for this itinerary yet.',
                  style: AppTypography.body(color: AppColors.textSecondary),
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
