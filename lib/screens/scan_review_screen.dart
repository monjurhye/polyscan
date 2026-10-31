import 'package:flutter/material.dart';

import '../models/document.dart';
import '../widgets/page_preview.dart';
import 'flows.dart';
import 'processing_screen.dart';

/// Review freshly scanned pages: filter, rotate, delete, add, then save.
class ScanReviewScreen extends StatefulWidget {
  const ScanReviewScreen({super.key, required this.pages});

  final List<ScanPage> pages;

  @override
  State<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends State<ScanReviewScreen> {
  late final List<ScanPage> _pages = [...widget.pages];
  final _controller = PageController(viewportFraction: 0.86);
  int _current = 0;
  DocType _type = DocType.auto;

  void _setType(DocType type) {
    setState(() {
      // Photos keep their own colors; switching back gives pages the document look again.
      if (type.isPhoto != _type.isPhoto) {
        for (final p in _pages) {
          p.filter = type.isPhoto ? PageFilter.original : PageFilter.color;
        }
      }
      _type = type;
    });
  }

  ScanPage get _page => _pages[_current];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    setState(() => _current = index);
    _controller.animateToPage(index, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  Future<void> _addPage(ScanSource source) async {
    final added = await pickPages(context, source);
    if (added.isEmpty || !mounted) return;
    setState(() => _pages.addAll(added));
    WidgetsBinding.instance.addPostFrameCallback((_) => _goTo(_pages.length - 1));
  }

  void _deletePage() {
    if (_pages.length == 1) {
      _discard();
      return;
    }
    setState(() {
      _pages.removeAt(_current);
      _current = _current.clamp(0, _pages.length - 1);
    });
  }

  Future<void> _discard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard scan?'),
        content: Text('${_pages.length} page(s) will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    // Photos aren't read as text.
    final codes = _type.isPhoto ? <String>[] : await pickRecognitionLanguages(context);
    if (codes == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ProcessingScreen(pages: _pages, languageCodes: codes, type: _type)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _discard();
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerHighest,
        appBar: AppBar(
          backgroundColor: scheme.surfaceContainerHighest,
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Discard', onPressed: _discard),
          title: Text('Page ${_current + 1} of ${_pages.length}'),
          actions: [
            PopupMenuButton<ScanSource>(
              tooltip: 'Add pages',
              onSelected: _addPage,
              itemBuilder: (_) => const [
                PopupMenuItem(value: ScanSource.camera, child: ListTile(leading: Icon(Icons.photo_camera_outlined), title: Text('Camera'))),
                PopupMenuItem(value: ScanSource.photos, child: ListTile(leading: Icon(Icons.photo_library_outlined), title: Text('Photos'))),
              ],
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [Icon(Icons.add_a_photo_outlined), SizedBox(width: 6), Text('Add')]),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  child: Center(child: PagePreview(page: _pages[i])),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final t in DocType.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        avatar: Icon(t.icon, size: 18),
                        label: Text(t.label),
                        selected: _type == t,
                        onSelected: (_) => _setType(t),
                      ),
                    ),
                ],
              ),
            ),
            if (_type == DocType.idCard)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Text('Scan the front, then the back. Each pair goes on one A4 page at real size.',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final f in PageFilter.values)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text(f.label),
                        selected: _page.filter == f,
                        onSelected: (_) => setState(() => _page.filter = f),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Tool(
                    icon: Icons.rotate_right,
                    label: 'Rotate',
                    onTap: () => setState(() => _page.quarterTurns = (_page.quarterTurns + 1) % 4),
                  ),
                  _Tool(icon: Icons.auto_fix_high_outlined, label: 'Auto', onTap: () => setState(() => _page.filter = PageFilter.color)),
                  _Tool(icon: Icons.delete_outline, label: 'Delete', onTap: _deletePage),
                ],
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                itemCount: _pages.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _goTo(i),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: i == _current ? scheme.primary : Colors.transparent, width: 2),
                    ),
                    child: PagePreview(page: _pages[i], radius: 3, elevated: false),
                  ),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _save,
                    child: Text('Save ${_pages.length == 1 ? '1 page' : '${_pages.length} pages'}'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon), const SizedBox(height: 4), Text(label, style: Theme.of(context).textTheme.labelSmall)],
        ),
      ),
    );
  }
}
