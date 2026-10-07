import 'package:polyscan_ocr/polyscan_ocr.dart';

import '../models/document.dart';
import 'model_store.dart';
import 'page_renderer.dart';

/// Reads the text on scanned pages, on the phone.
class OcrService {
  OcrService(this.models, this.renderer);

  final ModelStore models;
  final PageRenderer renderer;

  /// Recognizes every page in order and stores the result on the page.
  /// [onPage] is called with the 0-based index before each page starts.
  Future<void> recognizePages(
    List<ScanPage> pages,
    List<String> languageCodes, {
    void Function(int index)? onPage,
  }) async {
    final tessdata = (await models.directory()).path;
    for (var i = 0; i < pages.length; i++) {
      onPage?.call(i);
      final path = await renderer.render(pages[i]);
      pages[i].ocr = await PolyscanOcr.recognize(
        imagePath: path,
        tessdataDir: tessdata,
        languages: languageCodes,
      );
    }
  }
}
