import 'dart:math';

import 'package:flutter/material.dart';

import '../models/document.dart';

/// A4-shaped placeholder page drawn in code; replaced by the real scan image later.
class PagePreview extends StatelessWidget {
  const PagePreview({super.key, required this.page, this.elevated = true, this.radius = 6});

  final ScanPage page;
  final bool elevated;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: page.quarterTurns,
      child: AspectRatio(
        aspectRatio: 1 / 1.414,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            boxShadow: elevated
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 3))]
                : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: CustomPaint(painter: _PagePainter(page.seed, page.filter)),
          ),
        ),
      ),
    );
  }
}

class _PagePainter extends CustomPainter {
  _PagePainter(this.seed, this.filter);

  final int seed;
  final PageFilter filter;

  static const _accents = [Color(0xFF2F6BFF), Color(0xFFE5484D), Color(0xFF12A594)];

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(seed);
    final (paper, ink, text, accent) = switch (filter) {
      PageFilter.original => (const Color(0xFFE9E1CF), const Color(0xFF4A4A4A), const Color(0xFF9C978C), _accents[seed % 3].withValues(alpha: 0.7)),
      PageFilter.color => (Colors.white, const Color(0xFF1F2430), const Color(0xFF8A90A0), _accents[seed % 3]),
      PageFilter.grayscale => (const Color(0xFFF4F4F4), const Color(0xFF2A2A2A), const Color(0xFF9A9A9A), const Color(0xFF777777)),
      PageFilter.blackWhite => (Colors.white, Colors.black, const Color(0xFF3A3A3A), Colors.black),
    };

    final w = size.width, h = size.height;
    final m = w * 0.09;
    final r = Radius.circular(w * 0.008);
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);

    var y = m;
    canvas.drawCircle(Offset(w - m - w * 0.05, y + w * 0.05), w * 0.05, Paint()..color = accent);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(m, y, w * (0.35 + rnd.nextDouble() * 0.2), h * 0.022), r),
      Paint()..color = ink,
    );
    y += h * 0.04;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(m, y, w * 0.3, h * 0.012), r),
      Paint()..color = text,
    );
    y += h * 0.06;

    final textPaint = Paint()..color = text;
    final lineH = h * 0.011;
    final gap = h * 0.024;
    final full = w - 2 * m;
    while (y < h - m * 1.5) {
      final lines = 2 + rnd.nextInt(5);
      for (var i = 0; i < lines && y < h - m * 1.5; i++) {
        final len = i == lines - 1 ? full * (0.3 + rnd.nextDouble() * 0.5) : full * (0.88 + rnd.nextDouble() * 0.12);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(m, y, len, lineH), r), textPaint);
        y += gap;
      }
      y += gap * 0.8;
    }
  }

  @override
  bool shouldRepaint(_PagePainter old) => old.seed != seed || old.filter != filter;
}
