import 'dart:convert';
import 'dart:io';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/cached_itinerary_summary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract class ItineraryCache {
  Future<void> save(Itinerary itinerary);
  Future<Itinerary?> loadLatest();
  Future<List<CachedItinerarySummary>> listItineraries();
  Future<Itinerary?> loadItinerary(String id);
  Future<bool> deleteItinerary(String id);
}

typedef ItineraryCacheDirectoryLoader = Future<Directory> Function();

final itineraryCacheProvider = Provider<ItineraryCache>((ref) {
  return FileItineraryCache();
});

final cachedItinerariesProvider = FutureProvider<List<CachedItinerarySummary>>((ref) {
  final cache = ref.watch(itineraryCacheProvider);
  return cache.listItineraries();
});

class FileItineraryCache implements ItineraryCache {
  FileItineraryCache({
    ItineraryCacheDirectoryLoader? loadDocumentsDirectory,
    String fileName = 'nomad_latest_itinerary.json',
  }) : _loadDocumentsDirectory =
           loadDocumentsDirectory ?? getApplicationDocumentsDirectory,
       _fileName = fileName;

  final ItineraryCacheDirectoryLoader _loadDocumentsDirectory;
  final String _fileName;

  String _sanitize(String input) {
    return input.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase();
  }

  Future<Directory?> _getItinerariesDir() async {
    try {
      final docDir = await _loadDocumentsDirectory();
      final dir = Directory('${docDir.path}/itineraries');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    } on Exception {
      return null;
    }
  }

  @override
  Future<void> save(Itinerary itinerary) async {
    final dir = await _getItinerariesDir();
    if (dir == null) return;

    final now = DateTime.now().toUtc();
    final baseTime = itinerary.generatedAt.isNotEmpty
        ? itinerary.generatedAt
        : now.toIso8601String().split('.').first;

    final timestamp =
        baseTime
            .replaceAll(RegExp(r'[:\-]'), '')
            .replaceAll('T', '_')
            .replaceAll('Z', '') +
        '_${now.microsecondsSinceEpoch % 10000}';
        
    final sanitizedDest = _sanitize(itinerary.destination);
    final file = File('${dir.path}/${timestamp}_$sanitizedDest.json');

    final payload = jsonEncode(itinerary.toJson());
    try {
      await file.writeAsString(payload, flush: true);
      
      // Keep legacy file updated
      final fallback = await _tryResolveFile();
      if (fallback != null) {
        await fallback.writeAsString(payload, flush: true);
      }
    } on FileSystemException {
      return;
    }
  }

  @override
  Future<List<CachedItinerarySummary>> listItineraries() async {
    final dir = await _getItinerariesDir();
    if (dir == null) return [];

    try {
      final files = await dir.list().where((e) => e is File && e.path.endsWith('.json')).toList();
      final items = <CachedItinerarySummary>[];
      
      for (final f in files) {
        final file = f as File;
        try {
          final content = await file.readAsString();
          final decoded = jsonDecode(content) as Map<String, dynamic>;
          final parsed = Itinerary.fromJson(decoded.cast<String, Object?>());
          
          int venueCount = 0;
          for (final d in parsed.days) {
            venueCount += d.venues.length;
          }
          
          items.add(CachedItinerarySummary(
            id: file.uri.pathSegments.last,
            destination: parsed.destination,
            durationDays: parsed.durationDays,
            generatedAt: parsed.generatedAt,
            venueCount: venueCount,
          ));
        } catch (_) {
          // Ignore corrupt files
        }
      }
      
      items.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
      return items;
    } on Exception {
      return [];
    }
  }

  @override
  Future<Itinerary?> loadItinerary(String id) async {
    if (id.contains('/') || id.contains(r'\') || id.contains('..')) return null;
    final dir = await _getItinerariesDir();
    if (dir == null) return null;
    
    final file = File('${dir.path}/$id');
    if (!await file.exists()) return null;
    
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content) as Map<String, dynamic>;
      return Itinerary.fromJson(decoded.cast<String, Object?>());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<bool> deleteItinerary(String id) async {
    if (id.contains('/') || id.contains(r'\') || id.contains('..')) return false;
    final dir = await _getItinerariesDir();
    if (dir == null) return false;

    final file = File('${dir.path}/$id');
    if (await file.exists()) {
      try {
        await file.delete();
        return true;
      } catch (_) {
        return false;
      }
    }
    return false;

  @override
  Future<Itinerary?> loadLatest() async {
    // Try to get newest from itineraries folder first
    final list = await listItineraries();
    if (list.isNotEmpty) {
      final loaded = await loadItinerary(list.first.id);
      if (loaded != null) return loaded;
    }

    // Fallback to old legacy file
    final file = await _tryResolveFile();
    if (file == null) {
      return null;
    }
    if (!await file.exists()) {
      return null;
    }

    try {
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        return null;
      }

      final decoded = jsonDecode(content);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return Itinerary.fromJson(decoded.cast<String, Object?>());
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<File?> _tryResolveFile() async {
    try {
      final directory = await _loadDocumentsDirectory();
      return File('${directory.path}/$_fileName');
    } on MissingPlatformDirectoryException {
      return null;
    } on FileSystemException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
