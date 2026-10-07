import 'dart:io';

import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/ocr_language.dart';
import '../services/exporter.dart';
import '../services/model_store.dart';
import '../services/ocr_service.dart';
import '../services/page_importer.dart';
import '../services/page_renderer.dart';
import 'languages.dart';

/// App state. Documents are kept in memory for now; saving them across launches comes next.
class AppState extends ChangeNotifier {
  AppState({ModelStore? models, PageRenderer? renderer, PageImporter? importer})
      : models = models ?? ModelStore(),
        renderer = renderer ?? PageRenderer(),
        importer = importer ?? PageImporter(),
        languages = languageCatalog() {
    ocr = OcrService(this.models, this.renderer);
    exporter = Exporter(this.renderer);
  }

  /// Placeholder rule: free users can add this many paid-tier languages.
  static const freeDownloadLimit = 2;

  final ModelStore models;
  final PageRenderer renderer;
  final PageImporter importer;
  late final OcrService ocr;
  late final Exporter exporter;

  final List<ScanDocument> documents = [];
  final List<OcrLanguage> languages;
  final Map<String, double> downloadProgress = {};

  bool isPro = false;
  bool onboardingDone = false;
  ThemeMode themeMode = ThemeMode.system;
  ExportFormat defaultExport = ExportFormat.pdf;
  List<String> lastLanguageCodes = ['eng'];

  int _nextId = 1;

  /// Marks the models already on the phone as downloaded.
  Future<void> load() async {
    final installed = await models.installed();
    for (final lang in languages) {
      if (lang.status == LanguageStatus.builtIn) continue;
      lang.status = installed.contains(lang.code) ? LanguageStatus.downloaded : LanguageStatus.available;
    }
    notifyListeners();
  }

  List<OcrLanguage> get readyLanguages => languages.where((l) => l.isReady).toList();

  /// Downloaded languages that count toward the free limit.
  int get downloadedCount =>
      languages.where((l) => l.status == LanguageStatus.downloaded && !l.free).length;

  bool canDownload(OcrLanguage lang) => isPro || lang.free || downloadedCount < freeDownloadLimit;

  OcrLanguage? language(String code) {
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return null;
  }

  ScanDocument addDocument(List<ScanPage> pages, List<String> codes) {
    final now = DateTime.now();
    final doc = ScanDocument(
      id: 'd${_nextId++}',
      title: 'Scan ${formatDate(now)} ${_two(now.hour)}:${_two(now.minute)}',
      createdAt: now,
      pages: pages,
      languageCodes: codes,
    );
    documents.insert(0, doc);
    if (codes.isNotEmpty) lastLanguageCodes = codes;
    notifyListeners();
    return doc;
  }

  /// Runs OCR on every page of [doc]. Throws a PlatformException if Tesseract fails.
  Future<void> recognize(ScanDocument doc, List<String> codes, {void Function(int page)? onPage}) async {
    await ocr.recognizePages(doc.pages, codes, onPage: onPage);
    doc.languageCodes = codes;
    lastLanguageCodes = codes;
    notifyListeners();
  }

  void renameDocument(ScanDocument doc, String title) {
    doc.title = title;
    notifyListeners();
  }

  void deleteDocument(ScanDocument doc) {
    documents.remove(doc);
    for (final page in doc.pages) {
      final file = File(page.imagePath);
      if (file.existsSync()) file.deleteSync();
    }
    notifyListeners();
  }

  void addPages(ScanDocument doc, List<ScanPage> pages) {
    doc.pages.addAll(pages);
    notifyListeners();
  }

  void setPro(bool value) {
    isPro = value;
    notifyListeners();
  }

  void setOnboardingDone(bool value) {
    onboardingDone = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void setDefaultExport(ExportFormat format) {
    defaultExport = format;
    notifyListeners();
  }

  /// Downloads the model; progress shows in [downloadProgress]. Rethrows download errors.
  Future<void> downloadLanguage(OcrLanguage lang) async {
    if (downloadProgress.containsKey(lang.code)) return;
    downloadProgress[lang.code] = 0;
    notifyListeners();
    try {
      await models.download(lang.code, onProgress: (p) {
        downloadProgress[lang.code] = p;
        notifyListeners();
      });
      lang.status = LanguageStatus.downloaded;
    } finally {
      downloadProgress.remove(lang.code);
      notifyListeners();
    }
  }

  Future<void> removeLanguage(OcrLanguage lang) async {
    await models.remove(lang.code);
    lang.status = LanguageStatus.available;
    lastLanguageCodes.remove(lang.code);
    notifyListeners();
  }
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child})
      : super(notifier: state);

  /// Rebuilds the caller when state changes.
  static AppState of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// For callbacks; does not subscribe.
  static AppState read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

String formatDate(DateTime date) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String relativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, ${_two(date.hour)}:${_two(date.minute)}';
  if (diff == 1) return 'Yesterday';
  return formatDate(date);
}

String _two(int n) => n.toString().padLeft(2, '0');
