import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  // Load before the first frame so returning users don't see onboarding flash by.
  await state.load();
  // Write pending changes right away when the app is backgrounded; it may be killed there.
  AppLifecycleListener(onPause: state.save, onHide: state.save);
  runApp(PolyscanApp(state: state));
}

class PolyscanApp extends StatelessWidget {
  const PolyscanApp({super.key, required this.state});

  final AppState state;

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
          home: state.onboardingDone ? const HomeShell() : const OnboardingScreen(),
        ),
      ),
    );
  }
}
