import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/ocr_language.dart';
import 'pro_screen.dart';

class LanguagesScreen extends StatefulWidget {
  const LanguagesScreen({super.key});

  @override
  State<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends State<LanguagesScreen> {
  String _query = '';

  bool _matches(OcrLanguage l) {
    final q = _query.toLowerCase();
    return q.isEmpty || l.name.toLowerCase().contains(q) || l.nativeName.toLowerCase().contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    final ready = state.languages.where((l) => l.isReady && _matches(l)).toList();
    final available = state.languages.where((l) => !l.isReady && _matches(l)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Text languages')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SearchBar(
              hintText: 'Search 100+ languages',
              leading: const Icon(Icons.search),
              elevation: const WidgetStatePropertyAll(0),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          if (!state.isPro)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Card(
                color: theme.colorScheme.primaryContainer,
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_outlined, color: theme.colorScheme.onPrimaryContainer),
                  title: Text('${state.downloadedCount} of ${AppState.freeDownloadLimit} free downloads used'),
                  subtitle: const Text('Pro unlocks every language'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen())),
                ),
              ),
            ),
          _Header('On this phone'),
          for (final l in ready) _LanguageTile(lang: l),
          _Header('Download'),
          if (available.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('No matches')),
          for (final l in available) _LanguageTile(lang: l),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Languages are downloaded once and then work offline.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({required this.lang});

  final OcrLanguage lang;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final progress = state.downloadProgress[lang.code];

    final Widget trailing = switch (lang.status) {
      LanguageStatus.builtIn => const Chip(label: Text('Built-in'), visualDensity: VisualDensity.compact),
      LanguageStatus.downloaded => IconButton(
          tooltip: 'Remove',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => state.removeLanguage(lang),
        ),
      LanguageStatus.available when progress != null => SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(value: progress, strokeWidth: 3),
        ),
      LanguageStatus.available => TextButton.icon(
          onPressed: () {
            if (state.canDownload(lang)) {
              _download(context, state, lang);
            } else {
              Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProScreen()));
            }
          },
          icon: Icon(state.canDownload(lang) ? Icons.download_outlined : Icons.lock_outline, size: 18),
          label: Text('${lang.sizeMb.toStringAsFixed(1)} MB'),
        ),
    };

    final subtitle = [
      if (lang.nativeName != lang.name) lang.name,
      if (lang.free && lang.status == LanguageStatus.available && !state.isPro) 'Free',
    ].join(' · ');
    return ListTile(
      title: Text(lang.nativeName),
      subtitle: subtitle.isEmpty ? null : Text(subtitle),
      trailing: trailing,
    );
  }

  Future<void> _download(BuildContext context, AppState state, OcrLanguage lang) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await state.downloadLanguage(lang);
    } on Exception catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${lang.name} did not download. Check the connection and try again. ($e)')));
    }
  }
}
