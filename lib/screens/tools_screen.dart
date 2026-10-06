import 'package:flutter/material.dart';

import 'converter_screen.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          _ToolCard(
            icon: Icons.swap_horiz,
            title: 'Bijoy ↔ Unicode',
            subtitle: 'Convert old Bangla Bijoy text to Unicode and back',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ConverterScreen())),
          ),
          const SizedBox(height: 12),
          const _ToolCard(icon: Icons.draw_outlined, title: 'Sign PDF', subtitle: 'Add your signature to a document', soon: true),
          const SizedBox(height: 12),
          const _ToolCard(icon: Icons.call_merge, title: 'Merge & split', subtitle: 'Combine documents or pull pages out', soon: true),
          const SizedBox(height: 12),
          const _ToolCard(icon: Icons.lock_outline, title: 'Password protect', subtitle: 'Lock a PDF with a password', soon: true),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.title, required this.subtitle, this.onTap, this.soon = false});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool soon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        enabled: !soon,
        leading: CircleAvatar(
          backgroundColor: soon ? scheme.surfaceContainerHighest : scheme.primaryContainer,
          foregroundColor: soon ? scheme.outline : scheme.onPrimaryContainer,
          child: Icon(icon),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: soon ? const Chip(label: Text('Soon'), visualDensity: VisualDensity.compact) : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
