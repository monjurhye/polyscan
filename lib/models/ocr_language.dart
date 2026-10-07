enum LanguageStatus { builtIn, downloaded, available }

class OcrLanguage {
  OcrLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.sizeMb,
    this.free = false,
    this.status = LanguageStatus.available,
  });

  /// Tesseract code; the model file is `<code>.traineddata`.
  final String code;
  final String name;
  final String nativeName;

  /// Download size of the tessdata_fast model.
  final double sizeMb;

  /// Free downloads don't count toward the free tier's download limit.
  final bool free;
  LanguageStatus status;

  bool get isReady => status != LanguageStatus.available;
}
