import '../polyscan_ocr.dart';

/// Fixing Dhivehi: our fine-tuned `div` model (training/, 2026-10-29) reads the
/// letters well but writes each vowel mark (fili) before its letter, e.g.
/// "ޮކްނެމ" for "ކޮންމެ". Swapping every mark-letter pair back took held-out
/// phone photos from ~54% to ~93%. Correct Thaana never starts a word with a mark,
/// so the swap runs only when many words do; text from other models is left alone.

final _markThenLetter = RegExp('([ަ-ް])([ހ-ޥޱ])');
final _thaana = RegExp('[ހ-ޱ]');
final _startsWithMark = RegExp('^[ަ-ް]');

/// Share of Thaana words that must start with a mark before the text counts as
/// reversed. Measured: stock model at most 9%, our model 27–92%.
const reversedShare = 0.2;

bool thaanaMarksReversed(String text) {
  final words = text.split(RegExp(r'\s+')).where(_thaana.hasMatch).toList();
  if (words.isEmpty) return false;
  return words.where(_startsWithMark.hasMatch).length / words.length >= reversedShare;
}

String swapThaanaMarks(String text) => text.replaceAllMapped(_markThenLetter, (m) => '${m[2]}${m[1]}');

/// Returns [result] with marks moved after their letters, when the text is reversed.
OcrResult fixThaanaMarkOrder(OcrResult result) {
  if (!thaanaMarksReversed(result.text)) return result;
  return OcrResult(
    text: swapThaanaMarks(result.text),
    meanConfidence: result.meanConfidence,
    words: [
      for (final w in result.words)
        OcrWord(
          text: swapThaanaMarks(w.text),
          left: w.left,
          top: w.top,
          right: w.right,
          bottom: w.bottom,
          confidence: w.confidence,
        ),
    ],
    imageWidth: result.imageWidth,
    imageHeight: result.imageHeight,
    engine: result.engine,
  );
}
