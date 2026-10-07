import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/data/library_store.dart';
import 'package:polyscan/main.dart';

/// Real saves use an isolate, which never finishes inside testWidgets' fake time.
class _NoopLibrary extends LibraryStore {
  int saves = 0;

  @override
  Future<void> save(Library library) async => saves++;
}

void main() {
  testWidgets('onboarding leads to the document list', (tester) async {
    final library = _NoopLibrary();
    final state = AppState(library: library);
    await tester.pumpWidget(PolyscanApp(state: state));
    expect(find.text('Scan without strings'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Polyscan'), findsOneWidget);
    expect(find.text('No scans yet'), findsOneWidget);
    // Finishing onboarding is saved (debounced).
    await tester.pump(const Duration(seconds: 1));
    expect(library.saves, 1);
  });
}
