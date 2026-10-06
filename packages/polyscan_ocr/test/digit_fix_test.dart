import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/src/digit_fix.dart';

OcrWord _w(String text, int left, int right, {int top = 60, int bottom = 90, double conf = 90}) =>
    OcrWord(text: text, left: left, top: top, right: right, bottom: bottom, confidence: conf);

OcrResult _r(String text, List<OcrWord> words) =>
    OcrResult(text: text, meanConfidence: 80, words: words, imageWidth: 1240, imageHeight: 300);

void main() {
  test('number words are ASCII digits with number punctuation only', () {
    for (final yes in ['16', '6', '2026', '02/10/2026', '1,684.00', '4471229018', '(42)', '-5%']) {
      expect(isNumberWord(yes), isTrue, reason: yes);
    }
    for (final no in ['१६', '১৬', '١٦', 'INV-2026', 'No.', 'है।', '', '...', 'info@example.com', '447]']) {
      expect(isNumberWord(no), isFalse, reason: no);
    }
  });

  test('only non-Latin runs need the eng pass', () {
    expect(needsDigitFix(['eng']), isFalse);
    expect(needsDigitFix(['spa', 'eng']), isFalse);
    expect(needsDigitFix(['hin']), isTrue);
    expect(needsDigitFix(['ben', 'eng']), isTrue);
  });

  // Boxes taken from a real tesseract run on the Hindi sample.
  final hin = _r('तिथि 6 अक्टूबर 2026 है। संख्या 44722908 है।', [
    _w('तिथि', 300, 360),
    _w('6', 393, 408, conf: 0),
    _w('अक्टूबर', 420, 520),
    _w('2026', 543, 576, conf: 93),
    _w('है।', 600, 640),
    _w('संख्या', 700, 840),
    _w('44722908', 852, 1013, conf: 0),
    _w('है।', 1030, 1070),
  ]);
  final eng = _r('fefer 16 3teapar 2026 21 He 4471229018 21', [
    _w('fefer', 300, 360, conf: 40),
    _w('16', 376, 408, conf: 93),
    _w('3teapar', 420, 520, conf: 30),
    _w('2026', 528, 592, conf: 92),
    _w('21', 600, 640, conf: 66),
    _w('He', 700, 840, conf: 20),
    _w('4471229018', 856, 1028, conf: 92),
    _w('21', 1030, 1070, conf: 63),
  ]);

  test('confident eng numbers replace wrong digits; letters are never touched', () {
    final fixed = mergeEngNumbers(hin, eng);

    expect(fixed.text, 'तिथि 16 अक्टूबर 2026 है। संख्या 4471229018 है।');
    expect(fixed.words.map((w) => w.text), ['तिथि', '16', 'अक्टूबर', '2026', 'है।', 'संख्या', '4471229018', 'है।']);
    // The fixed word takes the eng box and confidence.
    expect(fixed.words[1].left, 376);
    expect(fixed.words[1].confidence, 93);
    // A number that was already right is left as it was.
    expect(fixed.words[3].left, 543);
  });

  test('a number split into pieces is joined back into one word', () {
    final split = _r('संख्या 447] 229048 है।', [
      _w('संख्या', 480, 590),
      _w('447]', 601, 648, conf: 0),
      _w('229048', 654, 715, conf: 0),
      _w('है।', 738, 760),
    ]);
    final engNumbers = _r('4471229018', [_w('4471229018', 606, 727, conf: 91)]);

    final fixed = mergeEngNumbers(split, engNumbers);

    expect(fixed.text, 'संख्या 4471229018 है।');
    expect(fixed.words.map((w) => w.text), ['संख्या', '4471229018', 'है।']);
  });

  test('low-confidence or misplaced eng numbers are ignored', () {
    final lowConf = _r('16', [_w('16', 376, 408, conf: 70)]);
    expect(mergeEngNumbers(hin, lowConf).text, hin.text);

    final otherLine = _r('16', [_w('16', 376, 408, top: 150, bottom: 180, conf: 95)]);
    expect(mergeEngNumbers(hin, otherLine).text, hin.text);
  });

  test('no edits returns the same result', () {
    expect(identical(applyWordEdits(hin), hin), isTrue);
  });
}
