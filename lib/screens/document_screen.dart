import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import '../widgets/page_preview.dart';
import 'flows.dart';
import 'page_viewer_screen.dart';

class DocumentScreen extends StatelessWidget {
  const DocumentScreen({super.key, required this.doc});

  final ScanDocument doc;

  @override
  Widget build(BuildContext context) {
    AppScope.of(context); // rebuild on rename / recognize
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: GestureDetector(onTap: () => _rename(context), child: Text(doc.title)),
          actions: [
            PopupMenuButton<String>(
              onSelected: (v) => switch (v) {
                'rename' => _rename(context),
                'add' => _addPages(context),
                'delete' => _delete(context),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
                PopupMenuItem(value: 'add', child: ListTile(leading: Icon(Icons.add_a_photo_outlined), title: Text('Add pages'))),
                PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
              ],
            ),
          ],
          bottom: TabBar(tabs: [
            Tab(text: 'Pages (${doc.pages.length})'),
            const Tab(text: 'Text'),
          ]),
        ),
        body: TabBarView(children: [_PagesTab(doc: doc), _TextTab(doc: doc)]),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: doc.hasText ? () => _copy(context, doc.recognizedText!) : null,
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy text'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                    onPressed: () => _showExport(context),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addPages(BuildContext context) async {
    final pages = await pickPages(context, ScanSource.photos);
    if (pages.isEmpty || !context.mounted) return;
    AppScope.read(context).addPages(doc, pages);
    if (doc.languageCodes.isNotEmpty) await readText(context, doc, doc.languageCodes);
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: doc.title);
    final title = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Rename'),
        content: TextField(controller: controller, autofocus: true, onSubmitted: (v) => Navigator.pop(c, v)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty && context.mounted) {
      AppScope.read(context).renameDocument(doc, title.trim());
    }
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text('"${doc.title}" will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      AppScope.read(context).deleteDocument(doc);
      Navigator.pop(context);
    }
  }

  void _showExport(BuildContext context) {
    final state = AppScope.read(context);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Share as', style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final f in ExportFormat.values)
              ListTile(
                leading: Icon(switch (f) {
                  ExportFormat.pdf => Icons.picture_as_pdf_outlined,
                  ExportFormat.word => Icons.article_outlined,
                  ExportFormat.txt => Icons.notes,
                  ExportFormat.jpg => Icons.image_outlined,
                }),
                title: Text(f.label),
                subtitle: Text(switch (f) {
                  ExportFormat.pdf => doc.hasText ? 'Text is selectable and searchable' : 'Image-only (recognize text first to search it)',
                  ExportFormat.word => 'Coming soon',
                  ExportFormat.txt => 'Just the text',
                  ExportFormat.jpg => 'One image per page',
                }),
                trailing: f == state.defaultExport ? const Chip(label: Text('Default')) : null,
                enabled: f != ExportFormat.word && (doc.hasText || f == ExportFormat.pdf || f == ExportFormat.jpg),
                onTap: () {
                  Navigator.pop(sheet);
                  _export(context, doc, f);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

Future<void> _export(BuildContext context, ScanDocument doc, ExportFormat format) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final size = MediaQuery.sizeOf(context);
  // Bottom centre, near the Share button; the iPad popover needs an anchor.
  final origin = Rect.fromLTWH(size.width / 2 - 1, size.height - 80, 2, 2);
  final done = showBusy(context, 'Preparing ${format.label}…');
  try {
    final files = await state.exporter.write(doc, format);
    done();
    await state.exporter.share(doc, files, origin: origin);
  } on Exception catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not export: $e')));
  } finally {
    done();
  }
}

void _copy(BuildContext context, String text) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Text copied')));
}

class _PagesTab extends StatelessWidget {
  const _PagesTab({required this.doc});

  final ScanDocument doc;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.66,
      ),
      itemCount: doc.pages.length,
      itemBuilder: (context, i) => InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PageViewerScreen(doc: doc, initialIndex: i)),
        ),
        child: Column(
          children: [
            Expanded(child: Center(child: PagePreview(page: doc.pages[i]))),
            const SizedBox(height: 6),
            Text('${i + 1}', style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _TextTab extends StatelessWidget {
  const _TextTab({required this.doc});

  final ScanDocument doc;

  Future<void> _reread(BuildContext context) async {
    final codes = await pickRecognitionLanguages(context);
    if (codes != null && codes.isNotEmpty && context.mounted) await readText(context, doc, codes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = AppScope.of(context);

    if (!doc.hasText) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.text_fields, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 12),
              Text('Text not recognized yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 6),
              Text(
                'Read the text to copy it, search it and make the PDF searchable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _reread(context),
                icon: const Icon(Icons.text_fields),
                label: const Text('Recognize text'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final code in doc.languageCodes)
              Chip(
                avatar: const Icon(Icons.translate, size: 16),
                label: Text(state.language(code)?.nativeName ?? code),
                visualDensity: VisualDensity.compact,
              ),
            TextButton(onPressed: () => _reread(context), child: const Text('Re-read')),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(doc.recognizedText!, style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Check important numbers against the original. Handwriting may not be read well.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
