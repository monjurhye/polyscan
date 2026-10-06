import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import '../widgets/page_preview.dart';
import 'document_screen.dart';
import 'flows.dart';

class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _query = '';
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final q = _query.toLowerCase();
    // Search also matches recognized text, which is the point of OCR.
    final docs = state.documents
        .where((d) => q.isEmpty || d.title.toLowerCase().contains(q) || (d.recognizedText?.toLowerCase().contains(q) ?? false))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Polyscan', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: _grid ? 'List view' : 'Grid view',
            icon: Icon(_grid ? Icons.view_list_outlined : Icons.grid_view_outlined),
            onPressed: () => setState(() => _grid = !_grid),
          ),
        ],
      ),
      body: state.documents.isEmpty
          ? const _EmptyState()
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: SearchBar(
                      hintText: 'Search titles and text inside scans',
                      leading: const Icon(Icons.search),
                      elevation: const WidgetStatePropertyAll(0),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ),
                if (docs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: Text('No documents match "$_query"')),
                  )
                else if (_grid)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverGrid.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.62,
                      ),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _DocCard(doc: docs[i]),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 120),
                    sliver: SliverList.builder(
                      itemCount: docs.length,
                      itemBuilder: (_, i) => _DocTile(doc: docs[i]),
                    ),
                  ),
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'import',
            tooltip: 'Import from photos or files',
            onPressed: () => showImportSheet(context),
            child: const Icon(Icons.photo_library_outlined),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan',
            onPressed: () => startScan(context, ScanSource.camera),
            icon: const Icon(Icons.document_scanner_outlined),
            label: const Text('Scan'),
          ),
        ],
      ),
    );
  }
}

void _open(BuildContext context, ScanDocument doc) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DocumentScreen(doc: doc)));
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.doc});

  final ScanDocument doc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _open(context, doc),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Center(
              child: Stack(
                children: [
                  PagePreview(page: doc.pages.first),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: _Badge(text: '${doc.pages.length}'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(
                child: Text(relativeDate(doc.createdAt),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ),
              if (doc.hasText) ...[
                const SizedBox(width: 6),
                Icon(Icons.text_fields, size: 14, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  const _DocTile({required this.doc});

  final ScanDocument doc;

  @override
  Widget build(BuildContext context) {
    final pages = doc.pages.length == 1 ? '1 page' : '${doc.pages.length} pages';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: SizedBox(width: 40, child: PagePreview(page: doc.pages.first, radius: 3, elevated: false)),
      title: Text(doc.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('$pages · ${relativeDate(doc.createdAt)}'),
      trailing: doc.hasText ? const Icon(Icons.text_fields, size: 18) : null,
      onTap: () => _open(context, doc),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(10)),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.document_scanner_outlined, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('No scans yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Tap Scan to capture a document. Everything stays on this phone.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
