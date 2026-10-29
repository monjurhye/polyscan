import 'package:flutter/material.dart' show IconData, Icons;
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

/// What was scanned. It sets the PDF page size and how pages are laid out.
enum DocType { auto, a4, letter, legal, idCard, photo }

extension DocTypeInfo on DocType {
  String get label => switch (this) {
        DocType.auto => 'Auto',
        DocType.a4 => 'A4',
        DocType.letter => 'Letter',
        DocType.legal => 'Legal',
        DocType.idCard => 'ID card',
        DocType.photo => 'Photo',
      };

  /// PDF page size in points (width, height), or null when each page follows its image.
  /// ID cards go on A4, two to a page (see PdfBuilder).
  (double, double)? get pageSize => switch (this) {
        DocType.a4 || DocType.idCard => (595.28, 841.89),
        DocType.letter => (612.0, 792.0),
        DocType.legal => (612.0, 1008.0),
        DocType.auto || DocType.photo => null,
      };

  IconData get icon => switch (this) {
        DocType.auto => Icons.auto_awesome_outlined,
        DocType.a4 || DocType.letter || DocType.legal => Icons.description_outlined,
        DocType.idCard => Icons.badge_outlined,
        DocType.photo => Icons.photo_outlined,
      };

  /// Photos keep their colors and aren't read as text.
  bool get isPhoto => this == DocType.photo;
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
    this.type = DocType.auto,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<ScanPage> pages;
  List<String> languageCodes;
  DocType type;

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
