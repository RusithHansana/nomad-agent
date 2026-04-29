import 'dart:io';

import 'package:app/core/models/itinerary.dart';
import 'package:app/core/models/venue.dart';
import 'package:app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

typedef DocumentsDirectoryLoader = Future<Directory> Function();

class PdfExportResult {
  const PdfExportResult({required this.filePath, required this.fileName});

  final String filePath;
  final String fileName;
}

Future<PdfExportResult> generateItineraryPdf(
  Itinerary itinerary, {
  DocumentsDirectoryLoader? loadDocumentsDirectory,
}) async {
  final baseFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'),
  );
  final cjkFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/NotoSansJP-Regular.ttf'),
  );

  final document = pw.Document(
    theme: pw.ThemeData.withFont(
      base: baseFont,
      bold: boldFont,
      fontFallback: [cjkFont],
    ),
  );
  final generatedAt = _resolveGeneratedAt(itinerary.generatedAt);

  document.addPage(
    pw.MultiPage(
      maxPages: 100,
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
      ),
      build: (context) {
        return [
          _buildHeader(itinerary: itinerary, generatedAt: generatedAt),
          pw.SizedBox(height: 20),
          ...itinerary.days.map(_buildDaySection),
          pw.SizedBox(height: 18),
          pw.Container(child: _buildCostSummary(itinerary)),
        ];
      },
    ),
  );

  final bytes = await document.save();
  final directoryLoader =
      loadDocumentsDirectory ?? getApplicationDocumentsDirectory;
  final rootDirectory = await directoryLoader();
  final exportDirectory = Directory(_joinPath(rootDirectory.path, 'exports'));
  await exportDirectory.create(recursive: true);

  final safeDestination = _sanitizeFileSegment(itinerary.destination);
  final exportedAt = DateTime.now().toUtc();
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(exportedAt);
  final fileName = '${timestamp}_${safeDestination}_itinerary.pdf';
  final file = File(_joinPath(exportDirectory.path, fileName));
  await file.writeAsBytes(bytes, flush: true);

  return PdfExportResult(filePath: file.path, fileName: fileName);
}

pw.Widget _buildHeader({
  required Itinerary itinerary,
  required DateTime generatedAt,
}) {
  final topColor = _pdfColorFrom(AppColors.primary);
  final bottomColor = _pdfColorFrom(AppColors.surfaceLight);
  final titleColor = _pdfColorFrom(AppColors.onPrimary);
  final textColor = _pdfColorFrom(AppColors.textPrimary);
  final subColor = _pdfColorFrom(AppColors.textSecondary);

  final dates = itinerary.days.map((day) {
    return _tryParseDate(day.date) ??
        generatedAt.add(Duration(days: day.dayNumber - 1));
  }).toList();

  final firstDate = dates.isEmpty
      ? null
      : dates.reduce((a, b) => a.isBefore(b) ? a : b);
  final lastDate = dates.isEmpty
      ? null
      : dates.reduce((a, b) => a.isAfter(b) ? a : b);

  final dateRange = switch ((firstDate, lastDate)) {
    (DateTime first, DateTime last) =>
      '${DateFormat('MMM d, yyyy').format(first)} - ${DateFormat('MMM d, yyyy').format(last)}',
    _ => 'Dates unavailable',
  };

  return pw.Container(
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(10),
      color: bottomColor,
      border: pw.Border.all(color: _pdfColorFrom(AppColors.secondaryVariant)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          decoration: pw.BoxDecoration(
            color: topColor,
            borderRadius: const pw.BorderRadius.only(
              topLeft: pw.Radius.circular(10),
              topRight: pw.Radius.circular(10),
            ),
          ),
          padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'NomadAgent',
                style: pw.TextStyle(
                  color: titleColor,
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Itinerary Export',
                style: pw.TextStyle(color: titleColor, fontSize: 11),
              ),
            ],
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(14),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                _sanitizeText(itinerary.destination),
                style: pw.TextStyle(
                  color: textColor,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                dateRange,
                style: pw.TextStyle(color: subColor, fontSize: 11),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Generated ${DateFormat('MMM d, yyyy - HH:mm').format(generatedAt.toLocal())}',
                style: pw.TextStyle(color: subColor, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildDaySection(DayPlan day) {
  final textColor = _pdfColorFrom(AppColors.textPrimary);
  final mutedColor = _pdfColorFrom(AppColors.textSecondary);

  final dayDate = _tryParseDate(day.date);
  final dayLabel = dayDate == null
      ? 'Day ${day.dayNumber}'
      : 'Day ${day.dayNumber} - ${DateFormat('EEEE, MMM d').format(dayDate)}';

  return pw.Container(
    margin: const pw.EdgeInsets.only(bottom: 14),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          dayLabel,
          style: pw.TextStyle(
            color: textColor,
            fontSize: 15,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 6),
        if (day.venues.isEmpty)
          pw.Text(
            'No venues available for this day yet.',
            style: pw.TextStyle(color: mutedColor, fontSize: 10),
          )
        else
          pw.Table(
            border: pw.TableBorder.all(
              color: _pdfColorFrom(AppColors.secondaryVariant),
              width: 0.5,
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(2.2),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1.2),
            },
            children: [_buildTableHeader(), ...day.venues.map(_buildVenueRow)],
          ),
      ],
    ),
  );
}

pw.TableRow _buildTableHeader() {
  return pw.TableRow(
    decoration: pw.BoxDecoration(color: _pdfColorFrom(AppColors.background)),
    children: [
      _cell('Venue', isHeader: true),
      _cell('Address', isHeader: true),
      _cell('Hours', isHeader: true),
      _cell('Rating', isHeader: true),
      _cell('Cost', isHeader: true),
    ],
  );
}

pw.TableRow _buildVenueRow(Venue venue) {
  final hours =
      (venue.openingHours?.where(
        (value) => value.trim().isNotEmpty,
      ))?.join(' | ') ??
      'N/A';
  return pw.TableRow(
    children: [
      _cell(_sanitizeText(venue.name)),
      _cell(_sanitizeText(venue.address)),
      _cell(_sanitizeText(hours)),
      _cell(venue.rating?.toStringAsFixed(1) ?? 'N/A'),
      _cell(_formatCost(venue.estimatedCost)),
    ],
  );
}

pw.Widget _buildCostSummary(Itinerary itinerary) {
  final textColor = _pdfColorFrom(AppColors.textPrimary);
  final categories = <String, double?>{
    'Food': itinerary.costSummary.food,
    'Entertainment': itinerary.costSummary.entertainment,
    'Transport': itinerary.costSummary.transport,
  };

  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: _pdfColorFrom(AppColors.secondaryVariant)),
      color: _pdfColorFrom(AppColors.surfaceLight),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Cost Summary',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
            color: textColor,
          ),
        ),
        pw.SizedBox(height: 8),
        ...itinerary.days.map((day) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Day ${day.dayNumber}'),
                pw.Text(_formatCost(day.estimatedDayCost)),
              ],
            ),
          );
        }),
        pw.Divider(color: _pdfColorFrom(AppColors.secondaryVariant)),
        ...categories.entries.map((entry) {
          return pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [pw.Text(entry.key), pw.Text(_formatCost(entry.value))],
            ),
          );
        }),
        pw.Divider(color: _pdfColorFrom(AppColors.secondaryVariant)),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Trip Total',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              _formatCost(itinerary.costSummary.total),
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _cell(String text, {bool isHeader = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.all(6),
    child: pw.Text(
      _sanitizeText(text),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
      ),
    ),
  );
}

DateTime _resolveGeneratedAt(String rawGeneratedAt) {
  final parsed = DateTime.tryParse(rawGeneratedAt);
  if (parsed != null) {
    return parsed;
  }
  return DateTime.now();
}

DateTime? _tryParseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _formatCost(double? value) {
  if (value == null) {
    return 'N/A';
  }
  final rounded = value.roundToDouble();
  if ((value - rounded).abs() < 0.01) {
    return '\$${rounded.toStringAsFixed(0)}';
  }
  return '\$${value.toStringAsFixed(2)}';
}

String _sanitizeFileSegment(String raw) {
  final candidate = raw
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  if (candidate.isEmpty) {
    return 'trip';
  }
  return candidate;
}

String _sanitizeText(String? text) {
  if (text == null || text.isEmpty) {
    return 'N/A';
  }

  final sanitized = StringBuffer();
  for (final rune in text.runes) {
    final isAllowedControl = rune == 0x0A;
    final isControl = rune < 0x20 || rune == 0x7F;
    if (isControl && !isAllowedControl) {
      continue;
    }

    sanitized.writeCharCode(rune);
  }

  final normalized = sanitized.toString().trim();
  if (normalized.isEmpty) {
    return 'N/A';
  }
  return normalized;
}

String _joinPath(String left, String right) {
  if (left.endsWith(Platform.pathSeparator)) {
    return '$left$right';
  }
  return '$left${Platform.pathSeparator}$right';
}

PdfColor _pdfColorFrom(Color color) {
  return PdfColor.fromInt(color.toARGB32());
}
