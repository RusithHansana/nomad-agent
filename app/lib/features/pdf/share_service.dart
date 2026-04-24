import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

abstract class PdfShareService {
  Future<void> sharePdf(String filePath);
}

final pdfShareServiceProvider = Provider<PdfShareService>((ref) {
  return SharePlusPdfShareService();
});

class SharePlusPdfShareService implements PdfShareService {
  @override
  Future<void> sharePdf(String filePath) {
    return Share.shareXFiles(
      <XFile>[XFile(filePath)],
      text: 'Sharing your NomadAgent itinerary PDF.',
      subject: 'NomadAgent itinerary export',
    );
  }
}
