import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import '../widgets/page_preview.dart';
import 'document_screen.dart';

/// Prepares the pages (rotation, filter) and reads their text, showing progress.
class ProcessingScreen extends StatefulWidget {
  const ProcessingScreen({super.key, required this.pages, required this.languageCodes});

  final List<ScanPage> pages;
  final List<String> languageCodes;

  @override
  State<ProcessingScreen> createState() => _ProcessingScreenState();
}

class _ProcessingScreenState extends State<ProcessingScreen> with SingleTickerProviderStateMixin {
  late final _scanLine = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  int _step = 0;
  int _page = 0;

  bool get _reads => widget.languageCodes.isNotEmpty;

  List<String> get _steps => ['Enhancing pages', if (_reads) 'Reading text'];

  @override
  void initState() {
    super.initState();
    // _run calls setState, which isn't allowed before the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final state = AppScope.read(context);
    var readFailed = false;
    try {
      for (var i = 0; i < widget.pages.length; i++) {
        setState(() => _page = i);
        await state.renderer.render(widget.pages[i]);
      }
      if (!mounted) return;
      setState(() => _step = 1);
      if (_reads) {
        try {
          await state.ocr.recognizePages(widget.pages, widget.languageCodes, onPage: (i) {
            if (mounted) setState(() => _page = i);
          });
        } on Exception catch (e) {
          readFailed = true;
          if (mounted) await _showError('Could not read the text', e);
        }
        if (mounted) setState(() => _step = 2);
      }
    } on Exception catch (e) {
      if (mounted) await _showError('Could not open this image', e);
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    final doc = state.addDocument(widget.pages, readFailed ? const [] : widget.languageCodes);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DocumentScreen(doc: doc)));
  }

  Future<void> _showError(String title, Exception error) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text('$error'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('OK'))],
        ),
      );

  @override
  void dispose() {
    _scanLine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = AppScope.of(context);
    final names = widget.languageCodes.map((c) => state.language(c)?.nativeName ?? c).join(', ');

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  width: 180,
                  child: Stack(
                    children: [
                      PagePreview(page: widget.pages.first),
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _scanLine,
                          builder: (_, _) => Align(
                            alignment: Alignment(0, _scanLine.value * 2 - 1),
                            child: Container(
                              height: 3,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                boxShadow: [BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.6), blurRadius: 12)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                for (var i = 0; i < _steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: i < _step
                              ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                              : i == _step
                                  ? const Padding(padding: EdgeInsets.all(3), child: CircularProgressIndicator(strokeWidth: 2.5))
                                  : Icon(Icons.circle_outlined, color: theme.colorScheme.outlineVariant),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            [
                              _steps[i] == 'Reading text' ? 'Reading text ($names)' : _steps[i],
                              if (i == _step && widget.pages.length > 1) ' · page ${_page + 1} of ${widget.pages.length}',
                            ].join(),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: i <= _step ? null : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Spacer(),
                Text('Working offline · nothing leaves your phone', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
