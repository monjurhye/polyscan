import 'package:flutter/material.dart';

import 'data/app_state.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState();
  state.load();
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
