// Arabic workaround check: write the invisible text layer without RTL reordering.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('arabic text layer in logical order', () async {
    final s = (jsonDecode(File('samples.json').readAsStringSync()) as Map)['ara'] as Map;
    final font = pw.Font.ttf(File('fonts/NotoSansArabic.ttf').readAsBytesSync().buffer.asByteData());
    final doc = pw.Document();
    doc.addPage(pw.Page(
      build: (_) => pw.Text(s['text'] as String,
          textDirection: pw.TextDirection.ltr,
          style: pw.TextStyle(font: font, fontSize: 16, renderingMode: PdfTextRenderingMode.invisible)),
    ));
    File('out/ara-ltr-layer.pdf').writeAsBytesSync(await doc.save());
  });
}
