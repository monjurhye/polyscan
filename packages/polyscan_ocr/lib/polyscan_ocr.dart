import 'dart:io';

import 'polyscan_ocr_platform_interface.dart';
import 'src/digit_fix.dart';

/// One recognized word and where it sits in the image (pixels, top-left origin).
class OcrWord {
  const OcrWord({
    required this.text,
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    required this.confidence,
  });

  factory OcrWord.fromMap(Map<dynamic, dynamic> map) => OcrWord(
        text: map['text'] as String,
        left: map['left'] as int,
        top: map['top'] as int,
        right: map['right'] as int,
        bottom: map['bottom'] as int,
        confidence: (map['confidence'] as num).toDouble(),
      );

  final String text;
  final int left;
  final int top;
  final int right;
  final int bottom;

  /// 0–100.
  final double confidence;

  @override
  String toString() => 'OcrWord("$text", $left,$top–$right,$bottom, ${confidence.toStringAsFixed(0)}%)';
}

class OcrResult {
  const OcrResult({
    required this.text,
    required this.meanConfidence,
    required this.words,
    required this.imageWidth,
    required this.imageHeight,
  });

  factory OcrResult.fromMap(Map<String, dynamic> map) => OcrResult(
        text: map['text'] as String,
        meanConfidence: map['meanConfidence'] as int,
        words: [for (final w in map['words'] as List) OcrWord.fromMap(w as Map)],
        imageWidth: map['imageWidth'] as int,
        imageHeight: map['imageHeight'] as int,
      );

  final String text;

  /// 0–100.
  final int meanConfidence;
  final List<OcrWord> words;
  final int imageWidth;
  final int imageHeight;
}

/// Page segmentation modes used by the app (subset of Tesseract's PSM values).
abstract final class PageSegMode {
  static const auto = 3;
  static const singleBlock = 6;
  static const singleLine = 7;
  static const sparseText = 11;
}

class PolyscanOcr {
  const PolyscanOcr._();

  static Future<String> tesseractVersion() => PolyscanOcrPlatform.instance.tesseractVersion();

  /// Reads the text in [imagePath].
  ///
  /// [tessdataDir] is a folder holding `<lang>.traineddata` files, e.g. models
  /// downloaded on demand; it must be named `tessdata` (Android requires it).
  /// [languages] are Tesseract codes such as `['ben', 'eng']`.
  ///
  /// With [fixDigits] (default), when a non-Latin model such as `hin` was used
  /// and the text contains Latin digits, a second `eng` pass reads the numbers
  /// and replaces the ones the main model got wrong (those models often drop
  /// digits). This needs `eng.traineddata` in [tessdataDir] and is skipped
  /// without it.
  ///
  /// Throws a `PlatformException` with code `bad_image`, `init_failed` or
  /// `recognize_failed`.
  static Future<OcrResult> recognize({
    required String imagePath,
    required String tessdataDir,
    required List<String> languages,
    int pageSegMode = PageSegMode.auto,
    Map<String, String> variables = const {},
    bool fixDigits = true,
  }) async {
    if (languages.isEmpty) throw ArgumentError.value(languages, 'languages', 'must not be empty');
    final map = await PolyscanOcrPlatform.instance.recognize(
      imagePath: imagePath,
      tessdataDir: tessdataDir,
      languages: languages.join('+'),
      pageSegMode: pageSegMode,
      variables: variables,
    );
    final result = OcrResult.fromMap(map);
    if (!fixDigits || !needsDigitFix(languages)) return result;
    if (!File('$tessdataDir/eng.traineddata').existsSync()) return result;
    return _fixDigits(result, imagePath, tessdataDir);
  }

  static Future<OcrResult> _fixDigits(OcrResult result, String imagePath, String tessdataDir) async {
    if (!result.words.any((w) => w.text.contains(RegExp('[0-9]')))) return result;
    final eng = await PolyscanOcrPlatform.instance.recognize(
      imagePath: imagePath,
      tessdataDir: tessdataDir,
      languages: 'eng',
      pageSegMode: PageSegMode.auto,
      variables: const {},
    );
    return mergeEngNumbers(result, OcrResult.fromMap(eng));
  }
}
