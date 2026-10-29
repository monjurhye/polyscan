import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/data/library_store.dart';
import 'package:polyscan/models/document.dart';
import 'package:polyscan/screens/unlock_screen.dart';
import 'package:polyscan/services/model_store.dart';

import 'fake_unlock_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  final states = <AppState>[];

  setUp(() => tmp = Directory.systemTemp.createTempSync('polyscan_unlock'));
  // Finish pending saves first: a store event schedules one, and on CI it once wrote
  // into the folder while it was being deleted.
  tearDown(() async {
    for (final state in states) {
      await state.save();
      state.dispose();
    }
    states.clear();
    tmp.deleteSync(recursive: true);
  });

  Future<AppState> loadedState(FakeUnlockStore store) async {
    final state = AppState(
        library: LibraryStore(baseDir: () async => tmp), models: ModelStore(baseDir: () async => tmp), store: store);
    states.add(state);
    await state.load();
    return state;
  }

  void scan(AppState state) => state.addDocument([ScanPage(imagePath: '${tmp.path}/p.jpg')], const []);

  test('the first ten scans are free, then scanning needs the unlock', () async {
    final state = await loadedState(FakeUnlockStore());
    for (var i = 0; i < AppState.freeScans; i++) {
      expect(state.canScan, isTrue, reason: 'scan ${i + 1}');
      scan(state);
    }
    expect(state.freeScansLeft, 0);
    expect(state.canScan, isFalse);
    expect(state.documents, hasLength(AppState.freeScans), reason: 'existing documents stay');
  });

  test('buying unlocks for good and survives a restart', () async {
    final store = FakeUnlockStore();
    final state = await loadedState(store);
    for (var i = 0; i < AppState.freeScans; i++) {
      scan(state);
    }
    await state.buyUnlock();
    expect(state.unlocked, isTrue);
    expect(state.canScan, isTrue);
    scan(state);
    expect(state.settings.scansUsed, AppState.freeScans, reason: 'scans after unlocking are not counted');

    await state.save();
    final reopened = await loadedState(FakeUnlockStore());
    expect(reopened.unlocked, isTrue);
    expect(reopened.settings.scansUsed, AppState.freeScans);
  });

  test('a failed purchase shows its message and keeps the app locked', () async {
    final state = await loadedState(FakeUnlockStore()..failWith = 'Payment declined');
    await state.buyUnlock();
    expect(state.unlocked, isFalse);
    expect(state.unlockError, 'Payment declined');
  });

  test('restore unlocks only when the store has the purchase', () async {
    final none = await loadedState(FakeUnlockStore());
    await none.restoreUnlock();
    expect(none.unlocked, isFalse);

    final owned = await loadedState(FakeUnlockStore(owned: true));
    await owned.restoreUnlock();
    expect(owned.unlocked, isTrue);
  });

  testWidgets('the unlock screen shows the store price and closes after buying', (tester) async {
    final state = AppState(
        library: LibraryStore(baseDir: () async => tmp),
        models: ModelStore(baseDir: () async => tmp),
        store: FakeUnlockStore(priceText: '₹199'));
    await tester.runAsync(state.load);
    // A phone-sized screen, tall enough that the buy button needs no scrolling.
    tester.view.physicalSize = const Size(1290, 2796);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(AppScope(
      state: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const UnlockScreen())),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock for ₹199'), findsOneWidget);
    expect(find.text('10 of 10 free scans left.'), findsOneWidget);

    await tester.tap(find.text('Unlock for ₹199'));
    await tester.pumpAndSettle();
    expect(state.unlocked, isTrue);
    expect(find.byType(UnlockScreen), findsNothing);
  });

  test('older settings files without the new fields load as locked with no scans used', () {
    final settings = Settings.fromJson({'onboardingDone': true});
    expect([settings.unlocked, settings.scansUsed], [false, 0]);
  });
}
