import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:polyscan/data/app_state.dart';
import 'package:polyscan/data/library_store.dart';
import 'package:polyscan/models/document.dart';
import 'package:polyscan/services/model_store.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late LibraryStore store;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('polyscan_library');
    store = LibraryStore(baseDir: () async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  String pageFile(String name) {
    final file = File('${tmp.path}/pages/$name')..createSync(recursive: true);
    file.writeAsBytesSync([1, 2, 3]);
    return file.path;
  }

  ScanDocument sampleDocument() => ScanDocument(
        id: 'd1',
        title: 'বিদ্যুৎ বিল',
        createdAt: DateTime.utc(2026, 10, 7, 9, 30),
        languageCodes: ['ben', 'eng'],
        pages: [
          ScanPage(imagePath: pageFile('a.jpg'), filter: PageFilter.blackWhite, quarterTurns: 3)
            ..ocr = const OcrResult(
              text: 'মোট ৳ 1,684',
              meanConfidence: 88,
              imageWidth: 1200,
              imageHeight: 1700,
              words: [OcrWord(text: 'মোট', left: 10, top: 20, right: 90, bottom: 60, confidence: 91.6)],
            ),
          ScanPage(imagePath: pageFile('b.jpg')),
        ],
      );

  test('documents and settings survive a save and load', () async {
    final settings = Settings(onboardingDone: true, themeMode: ThemeMode.dark, defaultExport: ExportFormat.txt, lastLanguageCodes: ['ben']);
    await store.save(Library(settings: settings, documents: [sampleDocument()]));

    final loaded = await store.load();
    expect(loaded.settings.onboardingDone, isTrue);
    expect(loaded.settings.themeMode, ThemeMode.dark);
    expect(loaded.settings.defaultExport, ExportFormat.txt);
    expect(loaded.settings.lastLanguageCodes, ['ben']);

    final doc = loaded.documents.single;
    expect(doc.title, 'বিদ্যুৎ বিল');
    expect(doc.createdAt, DateTime.utc(2026, 10, 7, 9, 30));
    expect(doc.languageCodes, ['ben', 'eng']);
    expect(doc.pages, hasLength(2));
    expect(File(doc.pages[0].imagePath).existsSync(), isTrue);
    expect(doc.pages[0].filter, PageFilter.blackWhite);
    expect(doc.pages[0].quarterTurns, 3);
    final ocr = doc.pages[0].ocr!;
    expect([ocr.text, ocr.meanConfidence, ocr.imageWidth, ocr.imageHeight], ['মোট ৳ 1,684', 88, 1200, 1700]);
    final word = ocr.words.single;
    expect([word.text, word.left, word.top, word.right, word.bottom, word.confidence], ['মোট', 10, 20, 90, 60, 92.0]);
    expect(doc.pages[1].ocr, isNull);
    expect(doc.recognizedText, 'মোট ৳ 1,684');
  });

  test('page paths are saved relative to the documents folder', () async {
    await store.save(Library(settings: Settings(), documents: [sampleDocument()]));
    final json = File('${tmp.path}/${LibraryStore.fileName}').readAsStringSync();
    expect(json, contains('"image":"pages/a.jpg"'));
    expect(json, isNot(contains(tmp.path.replaceAll('\\', '/'))));
  });

  test('a page image outside the documents folder keeps its absolute path', () async {
    final outside = Directory.systemTemp.createTempSync('polyscan_outside');
    addTearDown(() => outside.deleteSync(recursive: true));
    final path = (File('${outside.path}/x.jpg')..writeAsBytesSync([1])).path;
    final doc = ScanDocument(id: 'd2', title: 't', createdAt: DateTime(2026), pages: [ScanPage(imagePath: path)]);
    await store.save(Library(settings: Settings(), documents: [doc]));
    final loaded = (await store.load()).documents.single.pages.single.imagePath;
    expect(File(loaded).existsSync(), isTrue);
  });

  test('first launch gives an empty library', () async {
    final loaded = await store.load();
    expect(loaded.documents, isEmpty);
    expect(loaded.settings.onboardingDone, isFalse);
    expect(loaded.settings.lastLanguageCodes, ['eng']);
  });

  test('an unreadable file is kept aside and an empty library is returned', () async {
    File('${tmp.path}/${LibraryStore.fileName}').writeAsStringSync('{"documents": [ broken');
    final loaded = await store.load();
    expect(loaded.documents, isEmpty);
    final names = tmp.listSync().map((f) => f.uri.pathSegments.where((s) => s.isNotEmpty).last);
    expect(names.where((n) => n.startsWith('${LibraryStore.fileName}.unreadable-')), hasLength(1));
  });

  test('unused old page images are deleted, used and recent ones kept', () async {
    final doc = sampleDocument();
    final orphanOld = File(pageFile('orphan-old.jpg'))..setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    final orphanNew = File(pageFile('orphan-new.jpg'));
    for (final p in doc.pages) {
      File(p.imagePath).setLastModifiedSync(DateTime.now().subtract(const Duration(days: 2)));
    }
    await store.deleteUnusedPages([doc]);
    expect(orphanOld.existsSync(), isFalse);
    expect(orphanNew.existsSync(), isTrue);
    expect(doc.pages.every((p) => File(p.imagePath).existsSync()), isTrue);
  });

  test('AppState saves changes and a new AppState loads them', () async {
    AppState newState() => AppState(
          library: store,
          models: ModelStore(baseDir: () async => tmp),
        );

    final first = newState();
    await first.load();
    first.setOnboardingDone(true);
    final doc = first.addDocument([ScanPage(imagePath: pageFile('c.jpg'))], const []);
    first.renameDocument(doc, 'Receipt');
    await first.save();

    final second = newState();
    await second.load();
    expect(second.onboardingDone, isTrue);
    expect(second.documents.single.title, 'Receipt');

    second.deleteDocument(second.documents.single);
    await second.save();
    final third = newState();
    await third.load();
    expect(third.documents, isEmpty);
  });
}
