import 'dart:math';

import '../polyscan_ocr.dart';

/// Fixing numbers: models such as `hin` drop or merge Latin digits ("16" → "6",
/// "4471229018" → "44722908") and report ~0 confidence for them, while a full
/// `eng` pass over the same image reads those numbers correctly with high
/// confidence. These helpers merge the `eng` numbers into the main result.

/// Models that read Latin digits well themselves; no `eng` pass needed.
const latinDigitLanguages = {
  'eng', 'spa', 'fra', 'deu', 'por', 'ita', 'nld', 'ind', 'msa', 'vie', 'tur', 'fil', 'swa',
};

/// `eng` numbers below this confidence are ignored; on Hindi text `eng`
/// misreads some letters as short numbers ("21") at ~60–70.
const minNumberConfidence = 85.0;

final _numberWord = RegExp(r'^[0-9.,:/\-+%()]*[0-9][0-9.,:/\-+%()]*$');
final _asciiDigit = RegExp(r'[0-9]');

/// A word made only of ASCII digits and number punctuation, e.g. `16`, `02/10/2026`, `1,684.00`.
bool isNumberWord(String text) => _numberWord.hasMatch(text.trim());

/// Whether a run with [languages] should get the extra `eng` pass.
bool needsDigitFix(List<String> languages) => languages.any((l) => !latinDigitLanguages.contains(l));

/// Whether [inner] lies mostly inside [outer]: same line and at least half of its width covered.
bool _overlaps(OcrWord inner, OcrWord outer) {
  final yOverlap = min(inner.bottom, outer.bottom) - max(inner.top, outer.top);
  final minHeight = min(inner.bottom - inner.top, outer.bottom - outer.top);
  if (minHeight <= 0 || yOverlap < minHeight / 2) return false;
  final xOverlap = min(inner.right, outer.right) - max(inner.left, outer.left);
  final width = inner.right - inner.left;
  return width > 0 && xOverlap >= width / 2;
}

/// Replaces numbers in [main] with confident numbers from an [eng] pass over
/// the same image. Only words of [main] that contain ASCII digits are touched;
/// when [main] split one number into pieces, the first piece takes the whole
/// number and the rest are dropped. Fixed words take the `eng` box and confidence.
OcrResult mergeEngNumbers(OcrResult main, OcrResult eng, {double minConfidence = minNumberConfidence}) {
  final replace = <int, OcrWord>{};
  final drop = <int>{};
  for (final number in eng.words) {
    if (!isNumberWord(number.text) || number.confidence < minConfidence) continue;
    final pieces = [
      for (var i = 0; i < main.words.length; i++)
        if (!replace.containsKey(i) &&
            !drop.contains(i) &&
            _asciiDigit.hasMatch(main.words[i].text) &&
            _overlaps(main.words[i], number))
          i,
    ];
    if (pieces.isEmpty) continue;
    if (pieces.length == 1 && main.words[pieces.first].text == number.text) continue;
    replace[pieces.first] = number;
    drop.addAll(pieces.skip(1));
  }
  return applyWordEdits(main, replace: replace, drop: drop);
}

/// Returns [result] with words replaced or dropped, in both the word list and
/// the full text. Words are matched in reading order, so a repeated number is
/// only changed where it was edited.
OcrResult applyWordEdits(OcrResult result, {Map<int, OcrWord> replace = const {}, Set<int> drop = const {}}) {
  if (replace.isEmpty && drop.isEmpty) return result;

  final words = <OcrWord>[];
  final text = StringBuffer();
  var cursor = 0;
  for (var i = 0; i < result.words.length; i++) {
    final word = result.words[i];
    final at = result.text.indexOf(word.text, cursor);
    if (at >= 0) {
      text.write(result.text.substring(cursor, at));
      cursor = at + word.text.length;
      if (drop.contains(i)) {
        // Also drop the space that separated the dropped piece.
        if (cursor < result.text.length && result.text[cursor] == ' ') cursor++;
      } else {
        text.write(replace[i]?.text ?? word.text);
      }
    }
    if (drop.contains(i)) continue;
    words.add(replace[i] ?? word);
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
