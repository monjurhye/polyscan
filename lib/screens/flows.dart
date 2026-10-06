import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../data/mock_data.dart';
import '../models/document.dart';
import 'languages_screen.dart';
import 'scan_review_screen.dart';

/// Opens the review screen with demo pages until the camera scanner is wired in.
void startScan(BuildContext context, ScanSource source) {
  final pages = MockData.newPages(source == ScanSource.camera ? 3 : 1);
  Navigator.of(context).push(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => ScanReviewScreen(pages: pages)),
  );
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
            subtitle: const Text('Images or PDF'),
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
