// Generates the spike inputs: sample page images (clean + photo-like) and PDFs
// built with package:pdf, so OCR accuracy and PDF text handling can be measured.
// Run: flutter test test/generate_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const _width = 1240.0;
const _pad = 60.0;
const _fontSize = 34.0;

void main() {
  final samples = (jsonDecode(File('samples.json').readAsStringSync()) as Map<String, dynamic>)
      .map((k, v) => MapEntry(k, v as Map<String, dynamic>));
  final out = Directory('out')..createSync();

  testWidgets('render images and PDFs', (tester) async {
    await tester.runAsync(() async {
      for (final font in {for (final s in samples.values) s['font'] as String}) {
        await ui.loadFontFromList(File('fonts/$font.ttf').readAsBytesSync(), fontFamily: font);
      }
      // Mixed samples need a Latin fallback.
      await ui.loadFontFromList(File('fonts/NotoSans.ttf').readAsBytesSync(), fontFamily: 'NotoSans');

      for (final entry in samples.entries) {
        final key = entry.key.replaceAll('+', '_');
        final s = entry.value;
        final text = s['text'] as String;
        final font = s['font'] as String;
        final rtl = s['rtl'] as bool;

        final png = await _renderPng(text, font, rtl);
        File('${out.path}/$key-clean.png').writeAsBytesSync(png);
        File('${out.path}/$key-photo.jpg').writeAsBytesSync(_photoLike(png));

        final pdfFont = pw.Font.ttf(File('fonts/$font.ttf').readAsBytesSync().buffer.asByteData());
        final fallback = pw.Font.ttf(File('fonts/NotoSans.ttf').readAsBytesSync().buffer.asByteData());
        final dir = rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr;

        // 1) Visible text: shows whether shaping (conjuncts, joining) is correct.
        final visible = pw.Document();
        visible.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Text(text,
              textDirection: dir,
              style: pw.TextStyle(font: pdfFont, fontFallback: [fallback], fontSize: 18)),
        ));
        File('${out.path}/$key-visible.pdf').writeAsBytesSync(await visible.save());

        // 2) Searchable: page image with an invisible text layer on top, like the app will produce.
        final searchable = pw.Document();
        final image = pw.MemoryImage(png);
        searchable.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(children: [
            pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.contain, alignment: pw.Alignment.topCenter)),
            pw.Padding(
              padding: const pw.EdgeInsets.all(28),
              child: pw.Text(text,
                  textDirection: dir,
                  style: pw.TextStyle(
                    font: pdfFont,
                    fontFallback: [fallback],
                    fontSize: 16,
                    renderingMode: PdfTextRenderingMode.invisible,
                  )),
            ),
          ]),
        ));
        File('${out.path}/$key-searchable.pdf').writeAsBytesSync(await searchable.save());
      }
    });
  });
}

Future<Uint8List> _renderPng(String text, String font, bool rtl) async {
  final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
    textDirection: rtl ? ui.TextDirection.rtl : ui.TextDirection.ltr,
    textAlign: rtl ? ui.TextAlign.right : ui.TextAlign.left,
  ))
    ..pushStyle(ui.TextStyle(
      color: const ui.Color(0xFF111111),
      fontFamily: font,
      fontFamilyFallback: const ['NotoSans'],
      fontSize: _fontSize,
      height: 1.6,
    ))
    ..addText(text);
  final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: _width - 2 * _pad));
  final height = (paragraph.height + 2 * _pad).ceilToDouble();

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(ui.Rect.fromLTWH(0, 0, _width, height), ui.Paint()..color = const ui.Color(0xFFFFFFFF));
  canvas.drawParagraph(paragraph, const ui.Offset(_pad, _pad));
  final image = await recorder.endRecording().toImage(_width.toInt(), height.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Rough phone-photo simulation: lower resolution, slight tilt, blur, noise, JPEG artifacts.
Uint8List _photoLike(Uint8List png) {
  var im = img.decodePng(png)!;
  im = img.copyResize(im, width: (im.width * 0.7).round());
  im = img.copyRotate(im, angle: 1.5);
  im = img.gaussianBlur(im, radius: 1);
  im = img.noise(im, 18, type: img.NoiseType.gaussian);
  im = img.adjustColor(im, brightness: 0.95, contrast: 0.85);
  return img.encodeJpg(im, quality: 45);
}
