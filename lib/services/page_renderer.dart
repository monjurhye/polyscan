import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/document.dart';

/// A second way to clean a page for OCR, tried when the first reading had low confidence.
enum OcrRetry {
  /// Blur away sensor grain first (only for grainy pages, see [PageRenderer.isGrainy]).
  smooth,

  /// Sharpen soft, out-of-focus text first.
  sharpen,
}

/// Turns a page's original image into what the user sees: upright, filtered, and
/// at most [maxSide] pixels on its long side. The PDF uses this image.
///
/// OCR reads a separate image from [renderForOcr], cleaned up for text recognition.
/// It has the same aspect ratio, and the PDF scales word boxes by the OCR image's
/// own width, so the boxes still line up with the picture.
class PageRenderer {
  PageRenderer({Future<Directory> Function()? cacheDir}) : _cacheDir = cacheDir ?? getTemporaryDirectory;

  static const maxSide = 3000;

  /// OCR images smaller than this (long side) are enlarged, up to 2x, so letters
  /// are tall enough for Tesseract.
  static const ocrMinLongSide = 2200;

  final Future<Directory> Function() _cacheDir;

  /// Returns the path of a JPEG of the rendered page, reusing an earlier render.
  Future<String> render(ScanPage page) async {
    final filter = page.filter;
    final turns = page.quarterTurns % 4;
    final input = page.imagePath;
    return _cached(page, filter.name, (out) => renderFile(input, out, filter, turns));
  }

  /// Returns the path of the image OCR reads: the upright page after [enhanceForOcr].
  /// It doesn't depend on the page's filter, so the look the user picks never
  /// hurts recognition.
  Future<String> renderForOcr(ScanPage page) async {
    final turns = page.quarterTurns % 4;
    final input = page.imagePath;
    return _cached(page, 'ocr', (out) => renderOcrFile(input, out, turns));
  }

  /// The image for a second OCR pass with [retry], for pages whose normal OCR image
  /// read with low confidence. Null when that retry would not change the image
  /// ([OcrRetry.smooth] on a page without grain).
  Future<String?> renderForOcrRetry(ScanPage page, OcrRetry retry) async {
    final turns = page.quarterTurns % 4;
    final input = page.imagePath;
    final path = await _cached(page, 'ocr-${retry.name}', (out) => renderOcrFile(input, out, turns, retry: retry));
    return File(path).existsSync() ? path : null;
  }

  Future<String> _cached(ScanPage page, String variant, void Function(String out) work) async {
    final dir = Directory('${(await _cacheDir()).path}/rendered')..createSync(recursive: true);
    final source = File(page.imagePath);
    final stamp = source.lastModifiedSync().millisecondsSinceEpoch;
    final name = '${source.uri.pathSegments.last.split('.').first}-$stamp-$variant-${page.quarterTurns % 4}.jpg';
    final out = File('${dir.path}/$name');
    if (out.existsSync()) return out.path;

    final path = out.path;
    await Isolate.run(() => work(path));
    return path;
  }

  /// Pure function so it can run in an isolate and in tests.
  static void renderFile(String input, String output, PageFilter filter, int quarterTurns) {
    final image = applyFilter(_upright(input, quarterTurns), filter);
    File(output).writeAsBytesSync(img.encodeJpg(image, quality: 88));
  }

  /// Pure function so it can run in an isolate and in tests. With [OcrRetry.smooth]
  /// on a page without grain nothing is written (see [renderForOcrRetry]).
  static void renderOcrFile(String input, String output, int quarterTurns, {OcrRetry? retry}) {
    final upright = _upright(input, quarterTurns);
    if (retry == OcrRetry.smooth && !isGrainy(upright)) return;
    File(output).writeAsBytesSync(img.encodeJpg(enhanceForOcr(upright, retry: retry), quality: 92));
  }

  /// Decodes [input], applies EXIF orientation and [quarterTurns], and caps the size at [maxSide].
  static img.Image _upright(String input, int quarterTurns) {
    final decoded = img.decodeImage(File(input).readAsBytesSync());
    if (decoded == null) throw FormatException('Not an image: $input');
    var image = img.bakeOrientation(decoded);
    final longSide = math.max(image.width, image.height);
    if (longSide > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    if (quarterTurns != 0) image = img.copyRotate(image, angle: 90 * quarterTurns);
    return image;
  }

  static img.Image applyFilter(img.Image image, PageFilter filter) => switch (filter) {
        PageFilter.original => image,
        PageFilter.color => img.adjustColor(image, contrast: 1.15, saturation: 1.1),
        PageFilter.grayscale => img.grayscale(image),
        // Flattening the light first keeps text under a shadow from turning solid black.
        PageFilter.blackWhite =>
          img.luminanceThreshold(flattenLight(image), threshold: 0.6),
      };

  /// The image OCR reads: small pages enlarged (see [ocrMinLongSide]), then [flattenLight].
  /// A [retry] smooths or sharpens the enlarged page before flattening.
  ///
  /// On simulated phone scans this took English from 0–64% to 91–100% character
  /// accuracy under shadows and in low light (test of 2026-10-29).
  static img.Image enhanceForOcr(img.Image image, {OcrRetry? retry}) {
    final longSide = math.max(image.width, image.height);
    var factor = 1.0;
    if (longSide < ocrMinLongSide) {
      // Enlarged before flattening, so the denoise and the stretch work on the
      // bigger letters. Linear: a cubic resize took ~12 s per page.
      factor = math.min(2.0, ocrMinLongSide / longSide);
      image = img.copyResize(image,
          width: (image.width * factor).round(),
          height: (image.height * factor).round(),
          interpolation: img.Interpolation.linear);
    }
    final w = image.width, h = image.height;
    var lum = _luma(image);
    switch (retry) {
      case null:
        break;
      case OcrRetry.smooth:
        // Blur measured at the original size, so scale it with the enlargement.
        lum = _gaussian(lum, w, h, 1.2 * factor);
      case OcrRetry.sharpen:
        // Unsharp mask: add back the detail a blur removes.
        final blurred = _gaussian(lum, w, h, 1.5);
        for (var k = 0; k < lum.length; k++) {
          lum[k] = (2 * lum[k] - blurred[k]).clamp(0, 255);
        }
    }
    return _flatten(lum, w, h);
  }

  /// Whether [image] has visible sensor grain (photos in dim light): the typical
  /// difference between a pixel and its 3x3 median, robustly estimated, is over 4 levels.
  /// Clean and normal phone scans measured 0–3, dim-room photos 7.
  static bool isGrainy(img.Image image) {
    final lum = _luma(image);
    final med = _median3(lum, image.width, image.height);
    final histogram = List<int>.filled(511, 0);
    for (var k = 0; k < lum.length; k++) {
      histogram[lum[k] - med[k] + 255]++;
    }
    // Median absolute residual (the residual's own median is ~0 on a page).
    var seen = histogram[255], mad = 0;
    while (seen < lum.length / 2 && mad < 255) {
      mad++;
      seen += histogram[255 + mad] + histogram[255 - mad];
    }
    return 1.4826 * mad > 4;
  }

  /// A grayscale copy of [image] with even lighting: shadows, dim corners and grey
  /// paper become white, ink becomes black, and sensor noise is smoothed.
  static img.Image flattenLight(img.Image image) => _flatten(_luma(image), image.width, image.height);

  /// Rec. 601 luma of every pixel, in fixed point.
  static Uint8List _luma(img.Image image) {
    final rgb = image.convert(format: img.Format.uint8, numChannels: 3).getBytes(order: img.ChannelOrder.rgb);
    final lum = Uint8List(image.width * image.height);
    for (var k = 0, j = 0; k < lum.length; k++, j += 3) {
      lum[k] = (rgb[j] * 77 + rgb[j + 1] * 150 + rgb[j + 2] * 29) >> 8;
    }
    return lum;
  }

  static img.Image _flatten(Uint8List lum, int w, int h) {
    lum = _median3(lum, w, h);

    // The paper's brightness: the brightest nearby pixel, smoothed, on a small copy.
    final bg = _background(lum, w, h);

    // Divide by the paper so every part of the page has the same white.
    final flat = Uint8List(w * h);
    final histogram = List<int>.filled(256, 0);
    for (var k = 0; k < flat.length; k++) {
      final v = math.min(255, lum[k] * 255 ~/ math.max(bg[k], 1));
      flat[k] = v;
      histogram[v]++;
    }

    // Stretch: ink to black, paper to white. A page with little text has under 1%
    // ink pixels, so the ink level is capped rather than taken from a percentile alone.
    final ink = math.min(_percentile(histogram, flat.length, 0.002), 140);
    final paper = math.max(_percentile(histogram, flat.length, 0.6), ink + 1);
    final range = paper - ink;
    for (var k = 0; k < flat.length; k++) {
      flat[k] = ((flat[k] - ink) * 255 ~/ range).clamp(0, 255);
    }
    // Three equal channels: the JPEG encoder reads a one-channel image as red only,
    // which turns white into dark gray.
    return img.Image.fromBytes(width: w, height: h, bytes: flat.buffer, numChannels: 1).convert(numChannels: 3);
  }

  static int _percentile(List<int> histogram, int total, double q) {
    final target = total * q;
    var seen = 0;
    for (var v = 0; v < 256; v++) {
      seen += histogram[v];
      if (seen >= target) return v;
    }
    return 255;
  }

  /// 3x3 median filter (edges copied as they are).
  ///
  /// Each column of three is sorted once; the median of the 3x3 block is then the
  /// median of (max of the column minimums, median of the medians, min of the maximums).
  static Uint8List _median3(Uint8List src, int w, int h) {
    final dst = Uint8List.fromList(src);
    final lo = Uint8List(w), mid = Uint8List(w), hi = Uint8List(w);
    for (var y = 1; y < h - 1; y++) {
      final up = (y - 1) * w, row = y * w, down = (y + 1) * w;
      for (var x = 0; x < w; x++) {
        var a = src[up + x], b = src[row + x], c = src[down + x];
        if (a > b) (a, b) = (b, a);
        if (b > c) (b, c) = (c, b);
        if (a > b) (a, b) = (b, a);
        lo[x] = a;
        mid[x] = b;
        hi[x] = c;
      }
      for (var x = 1; x < w - 1; x++) {
        final maxLo = math.max(lo[x - 1], math.max(lo[x], lo[x + 1]));
        final minHi = math.min(hi[x - 1], math.min(hi[x], hi[x + 1]));
        var p = mid[x - 1], q = mid[x], r = mid[x + 1];
        if (p > q) (p, q) = (q, p);
        if (q > r) (q, r) = (r, q);
        if (p > q) (p, q) = (q, p);
        // Median of maxLo, q (median of medians) and minHi.
        var m1 = maxLo, m2 = q, m3 = minHi;
        if (m1 > m2) (m1, m2) = (m2, m1);
        if (m2 > m3) (m2, m3) = (m3, m2);
        if (m1 > m2) (m1, m2) = (m2, m1);
        dst[row + x] = m2;
      }
    }
    return dst;
  }

  /// Paper brightness at full size, estimated on a copy about 400 px on its long side:
  /// a max filter removes the letters, a blur smooths the result.
  static Uint8List _background(Uint8List lum, int w, int h) {
    final step = math.max(1, (math.max(w, h) / 400).ceil());
    final sw = (w + step - 1) ~/ step, sh = (h + step - 1) ~/ step;
    var small = Uint8List(sw * sh);
    for (var y = 0; y < sh; y++) {
      for (var x = 0; x < sw; x++) {
        var sum = 0, count = 0;
        for (var yy = y * step; yy < math.min(h, (y + 1) * step); yy++) {
          for (var xx = x * step; xx < math.min(w, (x + 1) * step); xx++) {
            sum += lum[yy * w + xx];
            count++;
          }
        }
        small[y * sw + x] = sum ~/ count;
      }
    }
    small = _maxFilter(small, sw, sh, 2);
    for (var pass = 0; pass < 3; pass++) {
      small = _boxBlur(small, sw, sh, 5);
    }

    // Bilinear upsampling back to full size, in 8-bit fixed point.
    final x0s = Int32List(w), x1s = Int32List(w), txs = Int32List(w);
    for (var x = 0; x < w; x++) {
      final fx = ((x + 0.5) / step - 0.5).clamp(0.0, sw - 1.0);
      x0s[x] = fx.floor();
      x1s[x] = math.min(x0s[x] + 1, sw - 1);
      txs[x] = ((fx - x0s[x]) * 256).round();
    }
    final out = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      final fy = ((y + 0.5) / step - 0.5).clamp(0.0, sh - 1.0);
      final r0 = fy.floor() * sw, r1 = math.min(fy.floor() + 1, sh - 1) * sw;
      final ty = ((fy - fy.floor()) * 256).round();
      for (var x = 0; x < w; x++) {
        final tx = txs[x], a = x0s[x], b = x1s[x];
        final top = small[r0 + a] * (256 - tx) + small[r0 + b] * tx;
        final bottom = small[r1 + a] * (256 - tx) + small[r1 + b] * tx;
        out[y * w + x] = (top * (256 - ty) + bottom * ty) >> 16;
      }
    }
    return out;
  }

  /// Separable max filter with the given radius.
  static Uint8List _maxFilter(Uint8List src, int w, int h, int r) {
    final tmp = Uint8List(w * h), dst = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var m = 0;
        for (var k = math.max(0, x - r); k <= math.min(w - 1, x + r); k++) {
          m = math.max(m, src[y * w + k]);
        }
        tmp[y * w + x] = m;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var m = 0;
        for (var k = math.max(0, y - r); k <= math.min(h - 1, y + r); k++) {
          m = math.max(m, tmp[k * w + x]);
        }
        dst[y * w + x] = m;
      }
    }
    return dst;
  }

  /// Separable Gaussian blur.
  static Uint8List _gaussian(Uint8List src, int w, int h, double sigma) {
    final r = (3 * sigma).ceil();
    final weights = [for (var i = -r; i <= r; i++) math.exp(-i * i / (2 * sigma * sigma))];
    final total = weights.reduce((a, b) => a + b);
    final k = [for (final v in weights) v / total];
    final tmp = Float32List(w * h), dst = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var acc = 0.0;
        for (var i = -r; i <= r; i++) {
          acc += src[y * w + (x + i).clamp(0, w - 1)] * k[i + r];
        }
        tmp[y * w + x] = acc;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var acc = 0.0;
        for (var i = -r; i <= r; i++) {
          acc += tmp[(y + i).clamp(0, h - 1) * w + x] * k[i + r];
        }
        dst[y * w + x] = acc.round().clamp(0, 255);
      }
    }
    return dst;
  }

  /// Separable box blur with the given radius (three passes approximate a Gaussian).
  static Uint8List _boxBlur(Uint8List src, int w, int h, int r) {
    final tmp = Uint8List(w * h), dst = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0, count = 0;
        for (var k = math.max(0, x - r); k <= math.min(w - 1, x + r); k++) {
          sum += src[y * w + k];
          count++;
        }
        tmp[y * w + x] = sum ~/ count;
      }
    }
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        var sum = 0, count = 0;
        for (var k = math.max(0, y - r); k <= math.min(h - 1, y + r); k++) {
          sum += tmp[k * w + x];
          count++;
        }
        dst[y * w + x] = sum ~/ count;
      }
    }
    return dst;
  }
}
