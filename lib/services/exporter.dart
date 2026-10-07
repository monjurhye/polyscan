import 'dart:io';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/document.dart';
import 'page_renderer.dart';
import 'pdf_builder.dart';

/// Writes a document out as PDF, text or images and opens the share sheet.
class Exporter {
  Exporter(this.renderer, {PdfBuilder? pdf}) : pdf = pdf ?? PdfBuilder();

  final PageRenderer renderer;
  final PdfBuilder pdf;

  /// Writes the export files (slow part; show progress around it).
  Future<List<File>> write(ScanDocument doc, ExportFormat format) async => switch (format) {
        ExportFormat.pdf => [await writePdf(doc)],
        ExportFormat.txt => [await _writeText(doc)],
        ExportFormat.jpg => await _writeImages(doc),
        ExportFormat.word => throw UnsupportedError('Word export is not built yet'),
      };

  /// Opens the share sheet. [origin] is where it points from; iPad requires it.
  Future<void> share(ScanDocument doc, List<File> files, {Rect? origin}) async {
    await SharePlus.instance.share(ShareParams(
      files: [for (final f in files) XFile(f.path)],
      subject: doc.title,
      sharePositionOrigin: origin,
    ));
  }

  Future<File> writePdf(ScanDocument doc) async {
    final inputs = [
      for (final page in doc.pages) PdfPageInput(await renderer.render(page), page.ocr),
    ];
    final file = File('${(await _outDir()).path}/${fileName(doc.title)}.pdf');
    return file.writeAsBytes(await pdf.build(inputs, title: doc.title), flush: true);
  }

  Future<File> _writeText(ScanDocument doc) async {
    final file = File('${(await _outDir()).path}/${fileName(doc.title)}.txt');
    return file.writeAsString(doc.recognizedText ?? '', flush: true);
  }

  Future<List<File>> _writeImages(ScanDocument doc) async {
    final dir = await _outDir();
    final base = fileName(doc.title);
    return [
      for (var i = 0; i < doc.pages.length; i++)
        await File(await renderer.render(doc.pages[i])).copy('${dir.path}/$base-${i + 1}.jpg'),
    ];
  }

  /// A fresh folder per export, so old files don't pile up or collide.
  Future<Directory> _outDir() async {
    final root = Directory('${(await getTemporaryDirectory()).path}/export');
    if (root.existsSync()) root.deleteSync(recursive: true);
    return root..createSync(recursive: true);
  }

  /// Keeps letters of every script; drops characters file systems reject.
  static String fileName(String title) {
    final cleaned = title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
    return cleaned.isEmpty ? 'Polyscan' : cleaned;
  }
}
