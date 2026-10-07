// Runs the real scan pipeline on a device: page image → render → Tesseract → searchable PDF.
// Android CI: flutter test integration_test -d emulator-5554

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/models/document.dart';

/// Draws [lines] in black on a white A4-ish page and saves it as a PNG.
Future<String> drawPage(List<String> lines) async {
  const width = 1240.0, height = 1754.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..drawRect(const Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);
  var y = 120.0;
  for (final line in lines) {
    final painter = TextPainter(
      text: TextSpan(text: line, style: const TextStyle(color: Colors.black, fontSize: 56)),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width - 200);
    painter.paint(canvas, Offset(100, y));
    y += painter.height + 40;
  }
  final image = await recorder.endRecording().toImage(width.toInt(), height.toInt());
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  final file = File('${(await getTemporaryDirectory()).path}/pipeline-page.png');
  await file.writeAsBytes(png!.buffer.asUint8List());
  return file.path;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a page goes through OCR into a searchable PDF', (tester) async {
    final state = AppState();
    await state.load();
    expect(state.language('eng')!.isReady, isTrue);

    final page = ScanPage(imagePath: await drawPage(['Polyscan works offline', 'Invoice number 4471229018']));
    final doc = state.addDocument([page], const []);
    final watch = Stopwatch()..start();
    await state.recognize(doc, ['eng']);
    // ignore: avoid_print
    print('PIPELINE_RESULT ocr ${watch.elapsedMilliseconds} ms: ${doc.recognizedText?.replaceAll('\n', ' ⏎ ')}');

    expect(doc.recognizedText, contains('Polyscan works offline'));
    expect(doc.recognizedText, contains('4471229018'));
    expect(page.ocr!.words, isNotEmpty);

    final pdf = await state.exporter.writePdf(doc);
    final bytes = await pdf.readAsBytes();
    // ignore: avoid_print
    print('PIPELINE_RESULT pdf ${bytes.length} bytes, ${page.ocr!.words.length} words in the text layer');
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
