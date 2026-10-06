import '../polyscan_ocr.dart';

/// Re-reading numbers: language models such as `hin` drop or merge Latin digits
/// ("16" → "6", "4471229018" → "44722908"), while `eng` restricted to digits
/// reads them reliably. These helpers pick the words to re-read and merge the
/// corrections back into the result.

/// Characters allowed when re-reading a number with `eng`.
const digitWhitelist = '0123456789.,:/-+%()';

/// Models whose own reading of Latin digits is already good; no re-read needed.
const latinDigitLanguages = {
  'eng', 'spa', 'fra', 'deu', 'por', 'ita', 'nld', 'ind', 'msa', 'vie', 'tur', 'fil', 'swa',
};

final _numberWord = RegExp(r'^[0-9.,:/\-+%()]*[0-9][0-9.,:/\-+%()]*$');

/// A word made only of ASCII digits and number punctuation, e.g. `16`, `02/10/2026`, `1,684.00`.
bool isNumberWord(String text) => _numberWord.hasMatch(text.trim());

/// Whether a run with [languages] should get its numbers re-read.
bool needsDigitFix(List<String> languages) => languages.any((l) => !latinDigitLanguages.contains(l));

/// Indexes of words worth re-reading.
List<int> digitCandidates(OcrResult result) => [
      for (var i = 0; i < result.words.length; i++)
        if (isNumberWord(result.words[i].text)) i,
    ];

/// The box to re-read for [word], padded so edge digits are not clipped.
List<int> paddedRegion(OcrWord word, int imageWidth, int imageHeight) {
  final height = word.bottom - word.top;
  final padY = (height * 0.25).round();
  // Keep horizontal padding small so neighbouring letters are not read as digits.
  final padX = (height * 0.2).round();
  return [
    (word.left - padX).clamp(0, imageWidth),
    (word.top - padY).clamp(0, imageHeight),
    (word.right + padX).clamp(0, imageWidth),
    (word.bottom + padY).clamp(0, imageHeight),
  ];
}

/// Whether a re-read should replace the original word.
bool acceptReread(OcrWord original, String reread, double rereadConfidence) {
  final text = reread.trim();
  if (text.isEmpty || text == original.text || !isNumberWord(text)) return false;
  return rereadConfidence >= 50;
}

/// Returns [result] with [fixes] (word index → new text) applied to both the
/// word list and the full text. Words are replaced in reading order, so a
/// number that appears twice is only changed where it was fixed.
OcrResult applyDigitFixes(OcrResult result, Map<int, String> fixes) {
  if (fixes.isEmpty) return result;

  final words = <OcrWord>[];
  final text = StringBuffer();
  var cursor = 0;
  for (var i = 0; i < result.words.length; i++) {
    final word = result.words[i];
    final replacement = fixes[i];
    final at = result.text.indexOf(word.text, cursor);
    if (at >= 0) {
      text
        ..write(result.text.substring(cursor, at))
        ..write(replacement ?? word.text);
      cursor = at + word.text.length;
    }
    words.add(replacement == null
        ? word
        : OcrWord(
            text: replacement,
            left: word.left,
            top: word.top,
            right: word.right,
            bottom: word.bottom,
            confidence: word.confidence,
          ));
  }
  text.write(result.text.substring(cursor));

  return OcrResult(
    text: text.toString(),
    meanConfidence: result.meanConfidence,
    words: words,
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
  );
}
