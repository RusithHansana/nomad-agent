import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Holds the captured map screenshot PNG bytes in memory.
///
/// Set by [ItineraryMapTab] after tiles load and the map is captured
/// via [RepaintBoundary]. Read by the PDF export flow to embed a real
/// map image in the exported PDF.
///
/// Reset to `null` when the itinerary screen is left.
final mapSnapshotProvider = StateProvider<Uint8List?>((ref) => null);
