import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:polyscan_ocr/polyscan_ocr.dart';

import '../models/document.dart';

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

  /// ID-1 card size (85.6 x 53.98 mm), the size of national ID, bank and most ID cards.
  static const cardWidth = 85.6 * PdfPageFormat.mm;
  static const cardHeight = 53.98 * PdfPageFormat.mm;

  /// [pages] pairs each rendered page image with its OCR result (null for image-only pages).
  ///
  /// [type] sets the layout: [DocType.auto] and [DocType.photo] size each page to its
  /// image; A4, Letter and Legal fit the image on a page of that size; [DocType.idCard]
  /// puts cards two to an A4 page (front above back) at their real size, ready to print.
  Future<Uint8List> build(List<PdfPageInput> pages, {String? title, DocType type = DocType.auto}) async {
    final fonts = _fonts ??= await _loadFonts();
    final doc = pw.Document(title: title, creator: 'Polyscan');
    final images = [for (final page in pages) pw.MemoryImage(await File(page.imagePath).readAsBytes())];

    if (type == DocType.idCard) {
      final (width, height) = type.pageSize!;
      for (var i = 0; i < pages.length; i += 2) {
        final children = <pw.Widget>[];
        for (var k = 0; k < 2 && i + k < pages.length; k++) {
          final image = images[i + k];
          final landscape = (image.width ?? 1) >= (image.height ?? 1);
          final boxWidth = landscape ? cardWidth : cardHeight;
          final boxHeight = landscape ? cardHeight : cardWidth;
          final box = _fit(image, (width - boxWidth) / 2, 72 + k * (cardWidth + 36), boxWidth, boxHeight);
          children.addAll(_placed(image, box, pages[i + k].ocr, fonts));
        }
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat(width, height),
          margin: pw.EdgeInsets.zero,
          build: (_) => pw.Stack(children: [pw.SizedBox(width: width, height: height), ...children]),
        ));
      }
      return doc.save();
    }

    final size = type.pageSize;
    for (var i = 0; i < pages.length; i++) {
      final image = images[i];
      final (width, height) = size ?? (pageWidth, pageWidth * (image.height ?? 1) / (image.width ?? 1));
      final box = _fit(image, 0, 0, width, height);
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat(width, height),
        margin: pw.EdgeInsets.zero,
        build: (_) => pw.Stack(children: [
          pw.SizedBox(width: width, height: height),
          ..._placed(image, box, pages[i].ocr, fonts),
        ]),
      ));
    }
    return doc.save();
  }

  /// The largest rectangle with [image]'s aspect ratio inside the given box, centered.
  static ({double left, double top, double width, double height}) _fit(
      pw.MemoryImage image, double left, double top, double width, double height) {
    final scale = math.min(width / (image.width ?? 1), height / (image.height ?? 1));
    final w = (image.width ?? 1) * scale, h = (image.height ?? 1) * scale;
    return (left: left + (width - w) / 2, top: top + (height - h) / 2, width: w, height: h);
  }

  /// The image in [box], with its invisible text layer on top.
  static List<pw.Widget> _placed(pw.MemoryImage image,
      ({double left, double top, double width, double height}) box, OcrResult? ocr, List<pw.Font> fonts) {
    return [
      pw.Positioned(
        left: box.left,
        top: box.top,
        child: pw.Image(image, width: box.width, height: box.height, fit: pw.BoxFit.fill),
      ),
      ..._textLayer(ocr, box, fonts),
    ];
  }

  static List<pw.Widget> _textLayer(
      OcrResult? ocr, ({double left, double top, double width, double height}) box, List<pw.Font> fonts) {
    if (ocr == null || ocr.imageWidth <= 0) return const [];
    // OCR boxes are in the pixels of the image Tesseract read, which has the page's aspect ratio.
    final scale = box.width / ocr.imageWidth;
    final words = <pw.Widget>[];
    for (final word in ocr.words) {
      final text = word.text.trim();
      if (text.isEmpty) continue;
      final height = (word.bottom - word.top) * scale;
      if (height <= 0) continue;
      words.add(pw.Positioned(
        left: box.left + word.left * scale,
        top: box.top + word.top * scale,
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

  /// The rendered page (see PageRenderer). OCR read a cleaned-up copy with the same
  /// aspect ratio, so the word boxes are scaled by the OCR image's own width.
  final String imagePath;
  final OcrResult? ocr;
}
