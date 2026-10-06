enum LanguageStatus { builtIn, downloaded, available }

class OcrLanguage {
  OcrLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.sizeMb,
    this.status = LanguageStatus.available,
  });

  final String code;
  final String name;
  final String nativeName;
  final double sizeMb;
  LanguageStatus status;

  bool get isReady => status != LanguageStatus.available;
}
