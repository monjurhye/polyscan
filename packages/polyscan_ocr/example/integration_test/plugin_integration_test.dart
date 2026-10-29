// Runs real Tesseract through the plugin on a device or simulator.
// iOS (Codemagic): flutter test integration_test -d <simulator id>

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr_example/ocr_samples.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late String tessdata;

  setUpAll(() async {
    tessdata = await prepareTessdata();
  });

  testWidgets('reports the Tesseract version', (tester) async {
    final version = await PolyscanOcr.tesseractVersion();
    // ignore: avoid_print
    print('OCR_RESULT tesseract $version');
    expect(version, startsWith('5.'));
  });

  for (final sample in ocrSamples) {
    testWidgets('reads ${sample.asset}', (tester) async {
      final run = await runSample(sample, tessdata);
      // ignore: avoid_print
      print('OCR_RESULT $run');
      // ignore: avoid_print
      print('OCR_TEXT ${run.result.text.replaceAll('\n', ' ⏎ ')}');

      expect(run.result.words, isNotEmpty);
      expect(run.result.imageWidth, greaterThan(0));
      final box = run.result.words.first;
      expect(box.right, greaterThan(box.left));
      expect(box.bottom, greaterThan(box.top));
      // Desktop tesseract.js scored 97–100% on these images; allow some slack.
      expect(run.accuracy, greaterThan(0.9), reason: run.result.text);
    });
  }

  for (final asset in ['assets/images/hin-clean.png', 'assets/images/hin-photo.jpg']) {
    testWidgets('Hindi numbers are fixed by the eng pass: $asset', (tester) async {
      final sample = OcrSample(asset, const ['hin'], 'hin');
      final before = await runSample(sample, tessdata, fixDigits: false);
      final after = await runSample(sample, tessdata);
      // ignore: avoid_print
      print('OCR_RESULT digit fix $asset: before ${(before.accuracy * 100).toStringAsFixed(1)}% '
          'after ${(after.accuracy * 100).toStringAsFixed(1)}% '
          '(${before.elapsed.inMilliseconds} -> ${after.elapsed.inMilliseconds} ms)');
      // ignore: avoid_print
      print('OCR_TEXT digit fix $asset: ${after.result.text.replaceAll('\n', ' ⏎ ')}');

      expect(after.result.text, contains('16 अक्टूबर'));
      expect(after.result.text, contains('2026'));
      expect(after.result.text, contains('4471229018'));
      expect(after.accuracy, greaterThanOrEqualTo(before.accuracy));
    });
  }

  testWidgets('iOS reads English with Apple Vision, Bangla with Tesseract', (tester) async {
    final eng = await runSample(const OcrSample('assets/images/eng-clean.png', ['eng'], 'eng'), tessdata);
    final tess = await runSample(const OcrSample('assets/images/eng-clean.png', ['eng'], 'eng'), tessdata,
        preferSystem: false);
    final ben = await runSample(const OcrSample('assets/images/ben-clean.png', ['ben'], 'ben'), tessdata);
    // ignore: avoid_print
    print('OCR_RESULT engine eng: ${eng.result.engine} ${(eng.accuracy * 100).toStringAsFixed(1)}% '
        '${eng.elapsed.inMilliseconds} ms; tesseract ${(tess.accuracy * 100).toStringAsFixed(1)}% '
        '${tess.elapsed.inMilliseconds} ms; ben: ${ben.result.engine}');
    // ignore: avoid_print
    print('OCR_TEXT vision eng: ${eng.result.text.replaceAll('\n', ' ⏎ ')}');

    expect(eng.result.engine, Platform.isIOS ? 'vision' : 'tesseract');
    expect(eng.accuracy, greaterThan(0.9), reason: eng.result.text);
    final box = eng.result.words.first;
    expect([box.right > box.left, box.bottom > box.top, box.right <= eng.result.imageWidth], [true, true, true]);
    expect(tess.result.engine, 'tesseract');
    expect(ben.result.engine, 'tesseract');
  });

  testWidgets('missing language fails with init_failed', (tester) async {
    final path = '${tessdata.replaceAll('/tessdata', '')}/eng-clean.png';
    await expectLater(
      PolyscanOcr.recognize(imagePath: path, tessdataDir: tessdata, languages: ['xyz']),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'init_failed')),
    );
  });

  testWidgets('unreadable image fails with bad_image', (tester) async {
    await expectLater(
      PolyscanOcr.recognize(imagePath: '/no/such/file.png', tessdataDir: tessdata, languages: ['eng']),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'bad_image')),
    );
  });
}
