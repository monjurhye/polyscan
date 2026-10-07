import 'dart:io';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:polyscan_ocr/polyscan_ocr.dart';

/// Builds searchable PDFs: each page is the scan image with an invisible text
/// layer placed over the words, so text can be searched, selected and copied.
///
/// The text is never drawn: `package:pdf` mis-shapes visible Bangla/Hindi text,
/// but its invisible layer extracts and searches correctly (risk spike, 2026-10-06).
class PdfBuilder {
  PdfBuilder({Future<List<pw.Font>> Function()? fonts}) : _loadFonts = fonts ?? _bundledFonts;

  /// Page width in points (A4 width); the height follows the image's aspect ratio.
  static const pageWidth = 595.0;

  final Future<List<pw.Font>> Function() _loadFonts;
  List<pw.Font>? _fonts;

  static const fontAssets = [
    'assets/fonts/NotoSans.ttf',
    'assets/fonts/NotoSansBengali.ttf',
    'assets/fonts/NotoSansDevanagari.ttf',
    'assets/fonts/NotoSansArabic.ttf',
    'assets/fonts/NotoSansThai.ttf',
  ];

  static Future<List<pw.Font>> _bundledFonts() async => [
        for (final asset in fontAssets) pw.Font.ttf(await rootBundle.load(asset)),
      ];

  /// [pages] pairs each rendered page image with its OCR result (null for image-only pages).
  Future<Uint8List> build(List<PdfPageInput> pages, {String? title}) async {
    final fonts = _fonts ??= await _loadFonts();
    final doc = pw.Document(title: title, creator: 'Polyscan');
    for (final page in pages) {
      final bytes = await File(page.imagePath).readAsBytes();
      final image = pw.MemoryImage(bytes);
      final pixelWidth = image.width ?? 1;
      final pixelHeight = image.height ?? 1;
      final scale = pageWidth / pixelWidth;
      final format = PdfPageFormat(pageWidth, pixelHeight * scale);

      doc.addPage(pw.Page(
        pageFormat: format,
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: [
          pw.Positioned.fill(child: pw.Image(image, fit: pw.BoxFit.fill)),
          ..._textLayer(page.ocr, format.width, fonts),
        ]),
      ));
    }
    return doc.save();
  }

  static List<pw.Widget> _textLayer(OcrResult? ocr, double pageWidth, List<pw.Font> fonts) {
    if (ocr == null || ocr.imageWidth <= 0) return const [];
    // OCR boxes are in the pixels of the image Tesseract read.
    final scale = pageWidth / ocr.imageWidth;
    final words = <pw.Widget>[];
    for (final word in ocr.words) {
      final text = word.text.trim();
      if (text.isEmpty) continue;
      final height = (word.bottom - word.top) * scale;
      if (height <= 0) continue;
      words.add(pw.Positioned(
        left: word.left * scale,
        top: word.top * scale,
        child: pw.Text(
          // The trailing space keeps words apart when the text is copied.
          '$text ',
          softWrap: false,
          maxLines: 1,
          style: pw.TextStyle(
            font: fonts.first,
            fontFallback: fonts.sublist(1),
            fontSize: height * 0.85,
            renderingMode: PdfTextRenderingMode.invisible,
          ),
        ),
      ));
    }
    return words;
  }
}

class PdfPageInput {
  const PdfPageInput(this.imagePath, this.ocr);

  /// The rendered page (see PageRenderer), the same image OCR read.
  final String imagePath;
  final OcrResult? ocr;
}
