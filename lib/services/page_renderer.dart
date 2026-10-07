import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/document.dart';

/// Turns a page's original image into what the user sees: upright, filtered, and
/// at most [maxSide] pixels on its long side. OCR and the PDF both use this
/// image, so word boxes line up with the picture in the PDF.
class PageRenderer {
  PageRenderer({Future<Directory> Function()? cacheDir}) : _cacheDir = cacheDir ?? getTemporaryDirectory;

  static const maxSide = 3000;

  final Future<Directory> Function() _cacheDir;

  /// Returns the path of a JPEG of the rendered page, reusing an earlier render.
  Future<String> render(ScanPage page) async {
    final dir = Directory('${(await _cacheDir()).path}/rendered')..createSync(recursive: true);
    final source = File(page.imagePath);
    final stamp = source.lastModifiedSync().millisecondsSinceEpoch;
    final name = '${source.uri.pathSegments.last.split('.').first}-$stamp-${page.filter.name}-${page.quarterTurns % 4}.jpg';
    final out = File('${dir.path}/$name');
    if (out.existsSync()) return out.path;

    final filter = page.filter;
    final turns = page.quarterTurns % 4;
    final input = page.imagePath;
    await Isolate.run(() => renderFile(input, out.path, filter, turns));
    return out.path;
  }

  /// Pure function so it can run in an isolate and in tests.
  static void renderFile(String input, String output, PageFilter filter, int quarterTurns) {
    final decoded = img.decodeImage(File(input).readAsBytesSync());
    if (decoded == null) throw FormatException('Not an image: $input');
    var image = img.bakeOrientation(decoded);
    final longSide = image.width > image.height ? image.width : image.height;
    if (longSide > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    if (quarterTurns != 0) image = img.copyRotate(image, angle: 90 * quarterTurns);
    image = applyFilter(image, filter);
    File(output).writeAsBytesSync(img.encodeJpg(image, quality: 88));
  }

  static img.Image applyFilter(img.Image image, PageFilter filter) => switch (filter) {
        PageFilter.original => image,
        PageFilter.color => img.adjustColor(image, contrast: 1.15, saturation: 1.1),
        PageFilter.grayscale => img.grayscale(image),
        PageFilter.blackWhite => img.luminanceThreshold(img.grayscale(image), threshold: 0.55),
      };
}
