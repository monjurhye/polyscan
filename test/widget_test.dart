import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/data/library_store.dart';
import 'package:polyscan/main.dart';
import 'package:polyscan/models/document.dart';
import 'package:polyscan/screens/document_screen.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

import 'fake_unlock_store.dart';

/// Real saves use an isolate, which never finishes inside testWidgets' fake time.
class _NoopLibrary extends LibraryStore {
  int saves = 0;

  @override
  Future<void> save(Library library) async => saves++;
}

void main() {
  testWidgets('onboarding leads to the document list', (tester) async {
    final library = _NoopLibrary();
    final state = AppState(library: library, store: FakeUnlockStore());
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

  testWidgets('recognized Arabic text is laid out right to left, English left to right', (tester) async {
    final state = AppState(library: _NoopLibrary(), store: FakeUnlockStore());
    ScanDocument doc(String text) => ScanDocument(
          id: text,
          title: 't',
          createdAt: DateTime(2026),
          pages: [
            ScanPage(imagePath: 'missing.png')
              ..ocr = OcrResult(text: text, meanConfidence: 90, words: const [], imageWidth: 1, imageHeight: 1),
          ],
        );
    for (final (text, direction) in [('المستوى: المتوسط', TextDirection.rtl), ('Amount due: \$48.70', TextDirection.ltr)]) {
      await tester.pumpWidget(AppScope(state: state, child: MaterialApp(home: DocumentScreen(doc: doc(text), initialTab: 1))));
      await tester.pumpAndSettle();
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).textDirection, direction, reason: text);
    }
  });
}
