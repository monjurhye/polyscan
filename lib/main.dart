import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'licenses.dart';
import 'screenshot_mode.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  final state = AppState();
  // Load before the first frame so returning users don't see onboarding flash by.
  await state.load();
  final scene = screenshotScene();
  if (scene != null) {
    // App Store screenshots: sample documents, no ads, nothing saved.
    runApp(PolyscanApp(state: state, home: await prepareScreenshot(state, scene)));
    return;
  }
  // Write pending changes right away when the app is backgrounded; it may be killed there.
  AppLifecycleListener(onPause: state.save, onHide: state.save);
  runApp(PolyscanApp(state: state));
  // Consent prompts and the ad SDK start after the first frame, so launch stays quick.
  if (!state.unlocked) WidgetsBinding.instance.addPostFrameCallback((_) => state.ads.start());
}

class PolyscanApp extends StatelessWidget {
  const PolyscanApp({super.key, required this.state, this.home});

  final AppState state;

  /// Replaces the normal first screen (screenshot mode).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: state,
      child: ListenableBuilder(
        listenable: state,
        builder: (context, _) => MaterialApp(
          title: 'Polyscan',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: state.themeMode,
          home: home ?? (state.onboardingDone ? const HomeShell() : const OnboardingScreen()),
        ),
      ),
    );
  }
}
