import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import '../widgets/page_preview.dart';
import 'document_screen.dart';

/// Shows progress while pages are enhanced, read and turned into a PDF.
/// Steps are timed fakes until the real pipeline exists.
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

  List<String> get _steps => [
        'Enhancing pages',
        if (widget.languageCodes.isNotEmpty) 'Reading text',
        'Building PDF',
      ];

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (var i = 0; i < _steps.length; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      setState(() => _step = i + 1);
    }
    final doc = AppScope.read(context).addDocument(widget.pages, widget.languageCodes);
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => DocumentScreen(doc: doc)));
  }

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
                            _steps[i] == 'Reading text' ? 'Reading text ($names)' : _steps[i],
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
