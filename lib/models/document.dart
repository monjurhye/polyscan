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
  ScanPage({required this.seed, this.filter = PageFilter.color, this.quarterTurns = 0});

  /// Drives the placeholder artwork until real images exist.
  final int seed;
  PageFilter filter;
  int quarterTurns;
}

class ScanDocument {
  ScanDocument({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.pages,
    this.languageCodes = const [],
    this.recognizedText,
  });

  final String id;
  String title;
  final DateTime createdAt;
  final List<ScanPage> pages;
  List<String> languageCodes;
  String? recognizedText;

  bool get hasText => recognizedText != null;
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
