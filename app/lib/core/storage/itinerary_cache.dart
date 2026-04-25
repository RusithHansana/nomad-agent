import 'dart:convert';
import 'dart:io';

import 'package:app/core/models/itinerary.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

abstract class ItineraryCache {
  Future<void> save(Itinerary itinerary);
  Future<Itinerary?> loadLatest();
}

typedef ItineraryCacheDirectoryLoader = Future<Directory> Function();

final itineraryCacheProvider = Provider<ItineraryCache>((ref) {
  return FileItineraryCache();
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

  @override
  Future<void> save(Itinerary itinerary) async {
    final file = await _tryResolveFile();
    if (file == null) {
      return;
    }

    final payload = jsonEncode(itinerary.toJson());
    try {
      await file.writeAsString(payload, flush: true);
    } on FileSystemException {
      // Export must remain non-fatal even if local storage is unavailable.
      return;
    }
  }

  @override
  Future<Itinerary?> loadLatest() async {
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
