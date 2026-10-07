import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:path_provider/path_provider.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

import '../models/document.dart';

/// Saves documents and settings to `library.json` in the app's documents folder.
///
/// Page images are stored as paths relative to that folder: on iOS the app's
/// container path changes between installs and updates.
class LibraryStore {
  LibraryStore({Future<Directory> Function()? baseDir}) : _baseDir = baseDir ?? getApplicationDocumentsDirectory;

  static const fileName = 'library.json';
  static const _version = 1;

  final Future<Directory> Function() _baseDir;

  Future<File> _file() async => File('${(await _baseDir()).path}/$fileName');

  /// Returns the saved library, or an empty one on first launch.
  ///
  /// A file that can't be read is renamed (kept, not deleted) and an empty
  /// library is returned, so a bad save never blocks the app from starting.
  Future<Library> load() async {
    final base = (await _baseDir()).path;
    final file = await _file();
    if (!file.existsSync()) return Library.empty();
    try {
      final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return decodeLibrary(json, base);
    } on Object catch (_) {
      await file.rename('${file.path}.unreadable-${DateTime.now().millisecondsSinceEpoch}');
      return Library.empty();
    }
  }

  /// Writes the whole library: encoded off the UI thread, then swapped in with a rename
  /// so a crash mid-write leaves the previous file intact.
  Future<void> save(Library library) async {
    final base = (await _baseDir()).path;
    final file = await _file();
    final json = encodeLibrary(library, base);
    final path = file.path;
    await Isolate.run(() {
      final tmp = File('$path.tmp')..writeAsStringSync(jsonEncode(json), flush: true);
      tmp.renameSync(path);
    });
  }

  /// Deletes page images under `pages/` that no document uses, e.g. from a scan
  /// that was discarded. Files younger than [minAge] are left alone, in case a
  /// scan is still being reviewed.
  Future<void> deleteUnusedPages(Iterable<ScanDocument> documents, {Duration minAge = const Duration(hours: 1)}) async {
    final dir = Directory('${(await _baseDir()).path}/pages');
    if (!dir.existsSync()) return;
    String key(String path) => File(path).absolute.path.replaceAll('\\', '/');
    final used = {for (final d in documents) for (final p in d.pages) key(p.imagePath)};
    final cutoff = DateTime.now().subtract(minAge);
    for (final file in dir.listSync().whereType<File>()) {
      if (!used.contains(key(file.path)) && file.lastModifiedSync().isBefore(cutoff)) {
        await file.delete();
      }
    }
  }

  static Map<String, dynamic> encodeLibrary(Library library, String base) => {
        'version': _version,
        'settings': library.settings.toJson(),
        'documents': [for (final d in library.documents) _encodeDocument(d, base)],
      };

  static Library decodeLibrary(Map<String, dynamic> json, String base) => Library(
        settings: Settings.fromJson((json['settings'] as Map?)?.cast<String, dynamic>() ?? const {}),
        documents: [
          for (final d in (json['documents'] as List? ?? const []).cast<Map<String, dynamic>>()) _decodeDocument(d, base),
        ],
      );

  static Map<String, dynamic> _encodeDocument(ScanDocument doc, String base) => {
        'id': doc.id,
        'title': doc.title,
        'createdAt': doc.createdAt.toIso8601String(),
        'languages': doc.languageCodes,
        'pages': [
          for (final p in doc.pages)
            {
              'image': _relative(p.imagePath, base),
              'filter': p.filter.name,
              'turns': p.quarterTurns,
              if (p.ocr != null) 'ocr': _encodeOcr(p.ocr!),
            },
        ],
      };

  static ScanDocument _decodeDocument(Map<String, dynamic> json, String base) => ScanDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        languageCodes: (json['languages'] as List? ?? const []).cast<String>(),
        pages: [
          for (final p in (json['pages'] as List).cast<Map<String, dynamic>>())
            ScanPage(
              imagePath: _absolute(p['image'] as String, base),
              filter: PageFilter.values.asNameMap()[p['filter']] ?? PageFilter.color,
              quarterTurns: p['turns'] as int? ?? 0,
            )..ocr = p['ocr'] == null ? null : _decodeOcr((p['ocr'] as Map).cast<String, dynamic>()),
        ],
      );

  /// Words are stored as compact arrays: [text, left, top, right, bottom, confidence].
  static Map<String, dynamic> _encodeOcr(OcrResult ocr) => {
        'text': ocr.text,
        'conf': ocr.meanConfidence,
        'w': ocr.imageWidth,
        'h': ocr.imageHeight,
        'words': [
          for (final w in ocr.words) [w.text, w.left, w.top, w.right, w.bottom, w.confidence.round()],
        ],
      };

  static OcrResult _decodeOcr(Map<String, dynamic> json) => OcrResult(
        text: json['text'] as String,
        meanConfidence: json['conf'] as int,
        imageWidth: json['w'] as int,
        imageHeight: json['h'] as int,
        words: [
          for (final w in (json['words'] as List).cast<List>())
            OcrWord(
              text: w[0] as String,
              left: w[1] as int,
              top: w[2] as int,
              right: w[3] as int,
              bottom: w[4] as int,
              confidence: (w[5] as num).toDouble(),
            ),
        ],
      );

  /// Paths outside the documents folder were stored absolute; keep them as they are.
  static String _absolute(String stored, String base) =>
      stored.startsWith('/') || RegExp(r'^[A-Za-z]:').hasMatch(stored) ? stored : '$base/$stored';

  static String _relative(String path, String base) {
    final normalized = path.replaceAll('\\', '/');
    final prefix = '${base.replaceAll('\\', '/')}/';
    return normalized.startsWith(prefix) ? normalized.substring(prefix.length) : normalized;
  }
}

class Library {
  Library({required this.settings, required this.documents});

  factory Library.empty() => Library(settings: Settings(), documents: []);

  final Settings settings;
  final List<ScanDocument> documents;
}

/// User preferences that survive restarts. (Pro status will come from the store receipt, not from here.)
class Settings {
  Settings({
    this.onboardingDone = false,
    this.themeMode = ThemeMode.system,
    this.defaultExport = ExportFormat.pdf,
    List<String>? lastLanguageCodes,
  }) : lastLanguageCodes = lastLanguageCodes ?? ['eng'];

  factory Settings.fromJson(Map<String, dynamic> json) => Settings(
        onboardingDone: json['onboardingDone'] as bool? ?? false,
        themeMode: ThemeMode.values.asNameMap()[json['themeMode']] ?? ThemeMode.system,
        defaultExport: ExportFormat.values.asNameMap()[json['defaultExport']] ?? ExportFormat.pdf,
        lastLanguageCodes: (json['lastLanguages'] as List?)?.cast<String>(),
      );

  bool onboardingDone;
  ThemeMode themeMode;
  ExportFormat defaultExport;
  List<String> lastLanguageCodes;

  Map<String, dynamic> toJson() => {
        'onboardingDone': onboardingDone,
        'themeMode': themeMode.name,
        'defaultExport': defaultExport.name,
        'lastLanguages': lastLanguageCodes,
      };
}
