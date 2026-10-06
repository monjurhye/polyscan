import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/document.dart';
import 'languages_screen.dart';
import 'pro_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final theme = Theme.of(context);
    void push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    void soon(String what) =>
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what opens here')));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Card(
              color: state.isPro ? theme.colorScheme.secondaryContainer : theme.colorScheme.primaryContainer,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: const Icon(Icons.workspace_premium, size: 32),
                title: Text(state.isPro ? 'Polyscan Pro' : 'Upgrade to Pro', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(state.isPro ? 'Thank you for your support!' : 'No ads, every language. Pay once.'),
                trailing: state.isPro ? null : const Icon(Icons.chevron_right),
                onTap: state.isPro ? null : () => push(const ProScreen()),
              ),
            ),
          ),
          const _Section('Text recognition'),
          ListTile(
            leading: const Icon(Icons.translate),
            title: const Text('Text languages'),
            subtitle: Text('${state.readyLanguages.length} on this phone'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => push(const LanguagesScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Default share format'),
            trailing: DropdownButton<ExportFormat>(
              value: state.defaultExport,
              underline: const SizedBox.shrink(),
              items: [for (final f in ExportFormat.values) DropdownMenuItem(value: f, child: Text(f.label))],
              onChanged: (f) => f == null ? null : state.setDefaultExport(f),
            ),
          ),
          const _Section('Appearance'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto_outlined)),
                ButtonSegment(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode_outlined)),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode_outlined)),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setThemeMode(s.first),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('App language'),
            subtitle: const Text('English'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => soon('Language list'),
          ),
          const _Section('Privacy'),
          const ListTile(
            leading: Icon(Icons.shield_outlined),
            title: Text('Everything stays on this phone'),
            subtitle: Text('No account, no cloud. Scans and text are never uploaded.'),
          ),
          const _Section('About'),
          ListTile(
            leading: const Icon(Icons.restore),
            title: const Text('Restore purchases'),
            onTap: () => soon('Restore'),
          ),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy policy'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => soon('Privacy policy'),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Support'),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () => soon('Support page'),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: const Text('Open-source licenses'),
            onTap: () => showLicensePage(context: context, applicationName: 'Polyscan', applicationVersion: '1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.replay),
            title: const Text('Show welcome screens'),
            onTap: () => state.setOnboardingDone(false),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text('Polyscan 1.0.0', style: theme.textTheme.bodySmall)),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
  }
}
