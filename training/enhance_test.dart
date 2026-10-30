// Runs the app's OCR preprocessing (PageRenderer.renderOcrFile) over a folder, so model
// evaluation sees what the app hands to Tesseract. Used by train-ocr.yml:
//   OCR_IN=<pngs> OCR_OUT=<jpgs> flutter test training/enhance_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/services/page_renderer.dart';

void main() {
  test('enhance', () {
    final out = Directory(Platform.environment['OCR_OUT']!)..createSync(recursive: true);
    // OCR_RETRY=smooth|sharpen writes the second-pass images instead.
    final retry = OcrRetry.values.where((r) => r.name == Platform.environment['OCR_RETRY']).firstOrNull;
    for (final f in Directory(Platform.environment['OCR_IN']!).listSync().whereType<File>()) {
      final name = f.uri.pathSegments.last.replaceAll('.png', '.jpg');
      PageRenderer.renderOcrFile(f.path, '${out.path}/$name', 0, retry: retry);
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
