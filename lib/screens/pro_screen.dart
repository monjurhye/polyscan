import 'package:flutter/material.dart';

import '../data/app_state.dart';

class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  // Placeholder; the real localized price comes from the store.
  static const _price = r'$4.99';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          children: [
            Center(
              child: CircleAvatar(
                radius: 40,
                backgroundColor: scheme.primaryContainer,
                child: Icon(Icons.workspace_premium, size: 44, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text('Polyscan Pro', textAlign: TextAlign.center, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Pay once. Yours forever.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            const _Feature(icon: Icons.block, title: 'No ads', text: 'A clean app, every time.'),
            const _Feature(icon: Icons.translate, title: 'Every language', text: 'Download as many of the 100+ text languages as you need.'),
            const _Feature(icon: Icons.auto_awesome_outlined, title: 'Every new tool', text: 'Sign, merge, split and password-protect PDFs as they arrive.'),
            const _Feature(icon: Icons.favorite_outline, title: 'Support independent work', text: 'Keeps Polyscan free of subscriptions and watermarks.'),
            const SizedBox(height: 28),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: state.isPro
                  ? null
                  : () {
                      state.setPro(true);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pro unlocked (demo)')));
                    },
              child: Text(state.isPro ? 'You have Pro' : 'Unlock Pro · $_price', style: const TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: () {}, child: const Text('Restore purchases')),
            const SizedBox(height: 8),
            Text(
              'One-time purchase. No subscription. No account needed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
