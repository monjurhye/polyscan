// Runs the real scan pipeline on a device: page image → render → Tesseract → searchable PDF.
// Android CI: flutter test integration_test -d emulator-5554

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/models/document.dart';

/// Draws [lines] in black on a white page with package:image's built-in font and saves a PNG.
/// (No engine rendering: Picture.toImage can wait on frames inside a test.)
Future<String> drawPage(List<String> lines) async {
  final image = img.Image(width: 1240, height: 1754)..clear(img.ColorRgb8(255, 255, 255));
  var y = 120;
  for (final line in lines) {
    img.drawString(image, line, font: img.arial48, x: 100, y: y, color: img.ColorRgb8(0, 0, 0));
    y += 100;
  }
  final file = File('${(await getTemporaryDirectory()).path}/pipeline-page.png');
  await file.writeAsBytes(img.encodePng(image));
  return file.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a page goes through OCR into a searchable PDF', (tester) async {
    final watch = Stopwatch()..start();
    // Logs each step and fails it after [limit], so a hang names the step.
    Future<T> step<T>(String name, Future<T> Function() body, {Duration limit = const Duration(minutes: 3)}) async {
      final start = watch.elapsedMilliseconds;
      // ignore: avoid_print
      print('PIPELINE_RESULT step $name: start at $start ms');
      final result = await body().timeout(limit, onTimeout: () => throw TimeoutException('step $name', limit));
      // ignore: avoid_print
      print('PIPELINE_RESULT step $name: ${watch.elapsedMilliseconds - start} ms');
      return result;
    }

    final state = AppState();
    await step('load models', state.load);
    expect(state.language('eng')!.isReady, isTrue);

    final path = await step('draw page', () => drawPage(['Polyscan works offline', 'Invoice number 4471229018']));
    final page = ScanPage(imagePath: path);
    final doc = state.addDocument([page], const []);
    await step('render page', () => state.renderer.render(page));
    await step('ocr', () => state.recognize(doc, ['eng']));
    // ignore: avoid_print
    print('PIPELINE_RESULT ocr text: ${doc.recognizedText?.replaceAll('\n', ' ⏎ ')}');

    expect(doc.recognizedText, contains('Polyscan works offline'));
    expect(doc.recognizedText, contains('4471229018'));
    expect(page.ocr!.words, isNotEmpty);

    final pdf = await step('pdf', () => state.exporter.writePdf(doc));
    final bytes = await pdf.readAsBytes();
    // ignore: avoid_print
    print('PIPELINE_RESULT pdf ${bytes.length} bytes, ${page.ocr!.words.length} words in the text layer');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');

    // Saved to the phone's documents folder and back, as after an app restart.
    await step('save', state.save);
    final reopened = AppState();
    await step('reload', reopened.load);
    final restored = reopened.documents.firstWhere((d) => d.id == doc.id);
    expect(restored.recognizedText, doc.recognizedText);
    expect(File(restored.pages.single.imagePath).existsSync(), isTrue);
    reopened.deleteDocument(restored);
    await reopened.save();
  }, timeout: const Timeout(Duration(minutes: 12)));
}
