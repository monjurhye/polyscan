import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/src/thaana_fix.dart';

OcrResult _r(String text) => OcrResult(
      text: text,
      meanConfidence: 80,
      words: [
        for (final w in text.split(' ')) OcrWord(text: w, left: 0, top: 0, right: 10, bottom: 10, confidence: 90),
      ],
      imageWidth: 100,
      imageHeight: 100,
    );

void main() {
  // Start of UDHR article 2 as our div model read it, and the printed text.
  const reversed = 'ަހަމ ޮކްނެމ މިަހަކްށެމ';
  const printed = 'ހަމަ ކޮންމެ މީހަކަށްމެ';

  test('reversed text gets every mark back after its letter', () {
    expect(thaanaMarksReversed(reversed), isTrue);
    final fixed = fixThaanaMarkOrder(_r(reversed));
    expect(fixed.text.split(' ').take(2).join(' '), 'ހަމަ ކޮންމެ');
    expect(fixed.words[1].text, 'ކޮންމެ');
  });

  test('correct text and other scripts are left alone', () {
    expect(thaanaMarksReversed(printed), isFalse);
    expect(fixThaanaMarkOrder(_r(printed)).text, printed);
    expect(fixThaanaMarkOrder(_r('Hello world')).text, 'Hello world');
    expect(thaanaMarksReversed(''), isFalse);
  });
}
