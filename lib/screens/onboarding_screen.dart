import 'package:flutter/material.dart';

import '../data/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      icon: Icons.document_scanner_outlined,
      title: 'Scan without strings',
      text: 'No subscription. No watermark on your PDFs. Ever.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Private by design',
      text: 'Works offline. No account, no cloud — your documents never leave your phone.',
    ),
    (
      icon: Icons.translate,
      title: 'Reads 100+ languages',
      text: 'English · हिन्दी · العربية · ไทย · Español · Русский · বাংলা and many more.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_index == _pages.length - 1) {
      AppScope.read(context).setOnboardingDone(true);
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final last = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton(
                onPressed: last ? null : () => AppScope.read(context).setOnboardingDone(true),
                child: Text(last ? '' : 'Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
                          child: Icon(p.icon, size: 68, color: scheme.onPrimaryContainer),
                        ),
                        const SizedBox(height: 40),
                        Text(p.title, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        Text(
                          p.text,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _index ? scheme.primary : scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
                onPressed: _next,
                child: Text(last ? 'Get started' : 'Next'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
