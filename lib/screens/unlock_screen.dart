import 'package:flutter/material.dart';

import '../data/app_state.dart';

/// The one-time "Remove ads" purchase, opened from Settings.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  late final Future<String?> _price = AppScope.read(context).store.price();
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final state = AppScope.of(context);

    if (state.unlocked) {
      // Bought or restored while this screen was open: close it on the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && Navigator.of(context).canPop()) Navigator.of(context).pop();
      });
    }

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
                child: Icon(Icons.block, size: 40, color: scheme.onPrimaryContainer),
              ),
            ),
            const SizedBox(height: 16),
            Text('Remove ads',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              'Polyscan is free with ads. Pay once to remove them forever.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            const _Feature(icon: Icons.block, title: 'No more ads', text: 'No banners and no full-screen ads, anywhere in the app.'),
            const _Feature(icon: Icons.payments_outlined, title: 'Pay once', text: 'No subscription. Yours forever.'),
            const _Feature(icon: Icons.all_inclusive, title: 'Everything else stays the same', text: 'Unlimited scans, every language and every format, with or without ads.'),
            const _Feature(icon: Icons.shield_outlined, title: 'Private', text: 'Your scans stay on this phone. No account needed.'),
            const SizedBox(height: 28),
            FutureBuilder<String?>(
              future: _price,
              builder: (context, snapshot) {
                final loading = snapshot.connectionState != ConnectionState.done;
                final price = snapshot.data;
                return FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy || loading || price == null ? null : () => _run(state.buyUnlock),
                  child: Text(
                    loading
                        ? 'Loading price…'
                        : price == null
                            ? 'App Store not available'
                            : 'Remove ads for $price',
                    style: const TextStyle(fontSize: 16),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : () => _run(state.restoreUnlock),
              child: const Text('Restore purchase'),
            ),
            if (state.unlockError != null) ...[
              const SizedBox(height: 8),
              Text(state.unlockError!, textAlign: TextAlign.center, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 8),
            Text(
              'One-time purchase. Works on all your devices with the same Apple ID.',
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
