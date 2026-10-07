import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import 'languages_screen.dart';
import 'scan_review_screen.dart';

/// Gets page images from [source]; shows an error and returns an empty list on failure.
Future<List<ScanPage>> pickPages(BuildContext context, ScanSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    return await AppScope.read(context).importer.pick(source);
  } on PlatformException catch (e) {
    messenger.showSnackBar(SnackBar(
      content: Text(e.code.contains('denied') || e.code.contains('access')
          ? 'Polyscan needs permission for ${source == ScanSource.camera ? 'the camera' : 'your photos'}. Allow it in Settings.'
          : 'Could not open ${source.name}: ${e.message ?? e.code}'),
    ));
    return [];
  }
}

/// Picks pages, then opens the review screen.
Future<void> startScan(BuildContext context, ScanSource source) async {
  final pages = await pickPages(context, source);
  if (pages.isEmpty || !context.mounted) return;
  Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScanReviewScreen(pages: pages)),
  );
}

/// Shows a modal progress dialog; call the returned function to close it.
VoidCallback showBusy(BuildContext context, String message) {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)),
          const SizedBox(width: 20),
          Expanded(child: Text(message)),
        ]),
      ),
    ),
  ).whenComplete(() => open = false);
  // Safe to call more than once.
  return () {
    if (!open) return;
    open = false;
    navigator.pop();
  };
}

/// Runs OCR on [doc] behind a progress dialog and reports failures.
Future<void> readText(BuildContext context, ScanDocument doc, List<String> codes) async {
  final state = AppScope.read(context);
  final messenger = ScaffoldMessenger.of(context);
  final done = showBusy(context, 'Reading text…');
  try {
    await state.recognize(doc, codes);
  } on Exception catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Could not read the text: $e')));
  } finally {
    done();
  }
}

void showImportSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('From Photos'),
            subtitle: const Text('Pick one or more images'),
            onTap: () {
              Navigator.pop(sheet);
              startScan(context, ScanSource.photos);
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('From Files'),
            subtitle: const Text('Image files'),
            onTap: () {
              Navigator.pop(sheet);
              startScan(context, ScanSource.files);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Asks which languages to read. Returns the chosen codes, an empty list to skip, or null if dismissed.
Future<List<String>?> pickRecognitionLanguages(BuildContext context) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _LanguagePickerSheet(),
  );
}

class _LanguagePickerSheet extends StatefulWidget {
  const _LanguagePickerSheet();

  @override
  State<_LanguagePickerSheet> createState() => _LanguagePickerSheetState();
}

class _LanguagePickerSheetState extends State<_LanguagePickerSheet> {
  late final Set<String> _selected = {...AppScope.read(context).lastLanguageCodes};

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final ready = state.readyLanguages;
    _selected.removeWhere((c) => !ready.any((l) => l.code == c));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recognize text', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Which languages are on these pages? Pick more than one for mixed text.',
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final lang in ready)
                  FilterChip(
                    label: Text(lang.nativeName),
                    selected: _selected.contains(lang.code),
                    onSelected: (on) => setState(() => on ? _selected.add(lang.code) : _selected.remove(lang.code)),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('More languages'),
                  onPressed: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const LanguagesScreen())),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Runs on this phone. Nothing is uploaded.', style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: const Text('Skip'),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _selected.isEmpty ? null : () => Navigator.pop(context, _selected.toList()),
                  icon: const Icon(Icons.text_fields),
                  label: const Text('Recognize'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
