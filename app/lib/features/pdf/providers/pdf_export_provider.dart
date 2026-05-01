import 'package:app/core/models/itinerary.dart';
import 'package:app/core/storage/itinerary_cache.dart';
import 'package:app/features/pdf/pdf_generator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PdfExportStatus { idle, generating, ready, error }

class PdfExportState {
  const PdfExportState({
    required this.status,
    this.filePath,
    this.errorMessage,
  });

  const PdfExportState.idle() : this(status: PdfExportStatus.idle);

  final PdfExportStatus status;
  final String? filePath;
  final String? errorMessage;

  PdfExportState copyWith({
    PdfExportStatus? status,
    String? filePath,
    String? errorMessage,
  }) {
    return PdfExportState(
      status: status ?? this.status,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

typedef GenerateItineraryPdf =
    Future<PdfExportResult> Function(
      Itinerary itinerary, {
      DocumentsDirectoryLoader? loadDocumentsDirectory,
    });

final pdfGeneratorProvider = Provider<GenerateItineraryPdf>((ref) {
  return generateItineraryPdf;
});

final pdfExportControllerProvider =
    AutoDisposeNotifierProvider<PdfExportController, PdfExportState>(
      PdfExportController.new,
    );

class PdfExportController extends AutoDisposeNotifier<PdfExportState> {
  @override
  PdfExportState build() {
    return const PdfExportState.idle();
  }

  Future<void> export({Itinerary? itinerary}) async {
    if (state.status == PdfExportStatus.generating) {
      return;
    }

    state = const PdfExportState(status: PdfExportStatus.generating);

    try {
      final itineraryToExport =
          itinerary ?? await ref.read(itineraryCacheProvider).loadLatest();
      if (itineraryToExport == null) {
        throw StateError('No itinerary available for offline export.');
      }

      final result = await ref.read(pdfGeneratorProvider)(itineraryToExport);
      state = PdfExportState(
        status: PdfExportStatus.ready,
        filePath: result.filePath,
      );
    } catch (e, stackTrace) {
      debugPrint('PDF Export failed: $e');
      debugPrint('Stack trace: $stackTrace');
      state = const PdfExportState(
        status: PdfExportStatus.error,
        errorMessage: 'Export failed. Please try again.',
      );
    }
  }

  void reset() {
    state = const PdfExportState.idle();
  }
}
