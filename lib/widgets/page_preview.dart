import 'dart:io';

import 'package:flutter/material.dart';

import '../models/document.dart';

/// Shows a page image with its rotation and filter applied.
///
/// Thumbnails are A4-shaped and cropped to fill; with [fullPage] the whole
/// image is shown at its own aspect ratio (page viewer).
class PagePreview extends StatelessWidget {
  const PagePreview({super.key, required this.page, this.elevated = true, this.radius = 6, this.fullPage = false});

  final ScanPage page;
  final bool elevated;
  final double radius;
  final bool fullPage;

  @override
  Widget build(BuildContext context) {
    Widget image = Image.file(
      File(page.imagePath),
      fit: fullPage ? BoxFit.contain : BoxFit.cover,
      // Thumbnails don't need full-resolution decodes.
      cacheWidth: fullPage ? null : 600,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFFE0E0E0),
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.black45)),
      ),
    );
    final matrix = filterMatrix(page.filter);
    if (matrix != null) image = ColorFiltered(colorFilter: ColorFilter.matrix(matrix), child: image);

    final framed = DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: elevated
            ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))]
            : null,
      ),
      child: ClipRRect(borderRadius: BorderRadius.circular(radius), child: image),
    );

    return RotatedBox(
      quarterTurns: page.quarterTurns,
      child: fullPage ? framed : AspectRatio(aspectRatio: 1 / 1.414, child: framed),
    );
  }
}

/// On-screen approximation of PageRenderer's filters.
List<double>? filterMatrix(PageFilter filter) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  switch (filter) {
    case PageFilter.original:
      return null;
    case PageFilter.color:
      const c = 1.15, t = -0.075 * 255;
      return [c, 0, 0, 0, t, 0, c, 0, 0, t, 0, 0, c, 0, t, 0, 0, 0, 1, 0];
    case PageFilter.grayscale:
      return [r, g, b, 0, 0, r, g, b, 0, 0, r, g, b, 0, 0, 0, 0, 0, 1, 0];
    case PageFilter.blackWhite:
      // Grayscale with very high contrast around the renderer's 0.55 threshold.
      const k = 6.0, t = -0.55 * 255 * k + 127.5;
      return [r * k, g * k, b * k, 0, t, r * k, g * k, b * k, 0, t, r * k, g * k, b * k, 0, t, 0, 0, 0, 1, 0];
  }
}
