import 'package:flutter/material.dart';

import '../models/document.dart';
import '../widgets/page_preview.dart';

class PageViewerScreen extends StatefulWidget {
  const PageViewerScreen({super.key, required this.doc, required this.initialIndex});

  final ScanDocument doc;
  final int initialIndex;

  @override
  State<PageViewerScreen> createState() => _PageViewerScreenState();
}

class _PageViewerScreenState extends State<PageViewerScreen> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.doc.pages.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.doc.pages.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 4,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: PagePreview(page: widget.doc.pages[i], elevated: false, radius: 2, fullPage: true),
            ),
          ),
        ),
      ),
    );
  }
}
