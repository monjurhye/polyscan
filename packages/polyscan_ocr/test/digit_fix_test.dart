import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/src/digit_fix.dart';

OcrWord _w(String text, [double conf = 80]) =>
    OcrWord(text: text, left: 100, top: 40, right: 140, bottom: 80, confidence: conf);

OcrResult _r(String text, List<OcrWord> words) =>
    OcrResult(text: text, meanConfidence: 80, words: words, imageWidth: 1000, imageHeight: 500);

void main() {
  test('number words are ASCII digits with number punctuation only', () {
    for (final yes in ['16', '6', '2026', '02/10/2026', '1,684.00', '4471229018', '(42)', '-5%']) {
      expect(isNumberWord(yes), isTrue, reason: yes);
    }
    for (final no in ['१६', '১৬', '١٦', 'INV-2026', 'No.', 'है।', '', '...', 'info@example.com']) {
      expect(isNumberWord(no), isFalse, reason: no);
    }
  });

  test('only non-Latin runs need a digit re-read', () {
    expect(needsDigitFix(['eng']), isFalse);
    expect(needsDigitFix(['spa', 'eng']), isFalse);
    expect(needsDigitFix(['hin']), isTrue);
    expect(needsDigitFix(['ben', 'eng']), isTrue);
  });

  test('padded region stays inside the image', () {
    final word = OcrWord(text: '16', left: 2, top: 1, right: 50, bottom: 41, confidence: 70);
    expect(paddedRegion(word, 52, 45), [0, 0, 52, 45]);
    expect(paddedRegion(_w('16'), 1000, 500), [92, 30, 148, 90]);
  });

  test('a re-read is accepted only if it is a confident, different number', () {
    expect(acceptReread(_w('6'), '16', 90), isTrue);
    expect(acceptReread(_w('6'), '16', 30), isFalse);
    expect(acceptReread(_w('16'), '16', 95), isFalse);
    expect(acceptReread(_w('6'), 'l6', 90), isFalse);
    expect(acceptReread(_w('6'), '   ', 90), isFalse);
  });

  test('fixes replace the right occurrence in text and words', () {
    final result = _r(
      'तिथि 6 अक्टूबर 2026 है। संख्या 44722908 है। फिर 6',
      [_w('तिथि'), _w('6'), _w('अक्टूबर'), _w('2026'), _w('है।'), _w('संख्या'), _w('44722908'), _w('है।'), _w('फिर'), _w('6')],
    );

    final fixed = applyDigitFixes(result, {1: '16', 6: '4471229018'});

    expect(fixed.text, 'तिथि 16 अक्टूबर 2026 है। संख्या 4471229018 है। फिर 6');
    expect(fixed.words[1].text, '16');
    expect(fixed.words[6].text, '4471229018');
    expect(fixed.words.last.text, '6');
    expect(fixed.words[1].left, 100);
  });

  test('no fixes returns the same result', () {
    final result = _r('a 1', [_w('a'), _w('1')]);
    expect(identical(applyDigitFixes(result, {}), result), isTrue);
  });
}
