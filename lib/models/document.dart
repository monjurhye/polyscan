import 'package:polyscan_ocr/polyscan_ocr.dart';

enum PageFilter { original, color, grayscale, blackWhite }

extension PageFilterLabel on PageFilter {
  String get label => switch (this) {
        PageFilter.original => 'Original',
        PageFilter.color => 'Color',
        PageFilter.grayscale => 'Grayscale',
        PageFilter.blackWhite => 'B & W',
      };
}

class ScanPage {
  ScanPage({required this.imagePath, this.filter = PageFilter.color, this.quarterTurns = 0});

  /// The page image as captured or imported, inside the app's documents folder.
  final String imagePath;
  PageFilter filter;
  int quarterTurns;

  /// Words and boxes from the last OCR run, in the upright (rotated) image's pixels.
  OcrResult? ocr;
}

class ScanDocument {
  ScanDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pages,
    this.languageCodes = const [],
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<ScanPage> pages;
  List<String> languageCodes;

  bool get hasText => pages.any((p) => p.ocr != null);

  /// All recognized text, pages separated by a blank line.
  String? get recognizedText {
    if (!hasText) return null;
    return pages.map((p) => p.ocr?.text.trim() ?? '').where((t) => t.isNotEmpty).join('\n\n');
  }
}

enum ExportFormat { pdf, word, txt, jpg }

extension ExportFormatLabel on ExportFormat {
  String get label => switch (this) {
        ExportFormat.pdf => 'Searchable PDF',
        ExportFormat.word => 'Word (.docx)',
        ExportFormat.txt => 'Plain text (.txt)',
        ExportFormat.jpg => 'Images (.jpg)',
      };
}

enum ScanSource { camera, photos, files }
