import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/ocr_language.dart';
import '../services/ad_service.dart';
import '../services/exporter.dart';
import '../services/model_store.dart';
import '../services/ocr_service.dart';
import '../services/page_importer.dart';
import '../services/page_renderer.dart';
import '../services/unlock_store.dart';
import 'languages.dart';
import 'library_store.dart';

/// App state. Documents and settings are saved to [LibraryStore] shortly after each change.
///
/// Polyscan is free, with ads ([AdService]). One in-app purchase ([UnlockStore])
/// removes the ads forever. No subscription and no scan limit.
class AppState extends ChangeNotifier {
  AppState({
    ModelStore? models,
    PageRenderer? renderer,
    PageImporter? importer,
    LibraryStore? library,
    UnlockStore? store,
    AdService? ads,
  })  : models = models ?? ModelStore(),
        renderer = renderer ?? PageRenderer(),
        importer = importer ?? PageImporter(),
        library = library ?? LibraryStore(),
        store = store ?? AppStoreUnlock(),
        ads = ads ?? AdService(),
        languages = languageCatalog() {
    ocr = OcrService(this.models, this.renderer);
    exporter = Exporter(this.renderer);
    // Banners appear once the ad SDK is ready.
    this.ads.addListener(notifyListeners);
  }

  final ModelStore models;
  final PageRenderer renderer;
  final PageImporter importer;
  final LibraryStore library;
  final UnlockStore store;
  final AdService ads;
  late final OcrService ocr;
  late final Exporter exporter;

  final List<ScanDocument> documents = [];
  final List<OcrLanguage> languages;
  final Map<String, double> downloadProgress = {};

  Settings settings = Settings();

  bool get onboardingDone => settings.onboardingDone;
  ThemeMode get themeMode => settings.themeMode;
  ExportFormat get defaultExport => settings.defaultExport;
  List<String> get lastLanguageCodes => settings.lastLanguageCodes;

  /// The one-time "Remove ads" purchase was bought or restored.
  bool get unlocked => settings.unlocked;

  /// Ads show until the purchase, and only once the ad SDK has started.
  bool get showAds => !unlocked && ads.ready;

  /// The latest purchase error from the store, for the unlock screen to show.
  String? unlockError;

  Timer? _saveTimer;
  Future<void> _lastSave = Future.value();
  StreamSubscription<UnlockEvent>? _storeEvents;

  /// Loads saved documents and settings, and marks the models already on the phone as downloaded.
  Future<void> load() async {
    _storeEvents ??= store.events.listen(_onStoreEvent);
    final saved = await library.load();
    settings = saved.settings;
    documents
      ..clear()
      ..addAll(saved.documents);
    final installed = await models.installed();
    for (final lang in languages) {
      if (lang.status == LanguageStatus.builtIn) continue;
      lang.status = installed.contains(lang.code) ? LanguageStatus.downloaded : LanguageStatus.available;
    }
    settings.lastLanguageCodes.removeWhere((c) => !(language(c)?.isReady ?? false));
    notifyListeners();
    unawaited(library.deleteUnusedPages(documents).catchError((Object e) => debugPrint('Page cleanup failed: $e')));
  }

  /// Notifies listeners and saves soon; quick successive changes are written once.
  void _changed() {
    notifyListeners();
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), save);
  }

  /// Writes the library now (waits for any save already running). Saves run one at a time.
  Future<void> save() {
    _saveTimer?.cancel();
    final snapshot = Library(settings: settings, documents: List.of(documents));
    return _lastSave = _lastSave.then((_) => library.save(snapshot)).catchError((Object e) {
      debugPrint('Saving the library failed: $e');
    });
  }

  List<OcrLanguage> get readyLanguages => languages.where((l) => l.isReady).toList();

  OcrLanguage? language(String code) {
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return null;
  }

  ScanDocument addDocument(List<ScanPage> pages, List<String> codes, {DocType type = DocType.auto}) {
    final now = DateTime.now();
    final doc = ScanDocument(
      id: 'd${now.microsecondsSinceEpoch}',
      title: '${type == DocType.auto ? 'Scan' : type.label} ${formatDate(now)} ${_two(now.hour)}:${_two(now.minute)}',
      createdAt: now,
      pages: pages,
      languageCodes: codes,
      type: type,
    );
    documents.insert(0, doc);
    if (codes.isNotEmpty) settings.lastLanguageCodes = codes;
    _changed();
    return doc;
  }

  void _onStoreEvent(UnlockEvent event) {
    switch (event) {
      case Unlocked():
        settings.unlocked = true;
        unlockError = null;
        ads.stop();
      case UnlockFailed(:final message):
        unlockError = message;
    }
    _changed();
  }

  Future<void> buyUnlock() {
    unlockError = null;
    notifyListeners();
    return ads.hold(store.buy);
  }

  Future<void> restoreUnlock() {
    unlockError = null;
    notifyListeners();
    return ads.hold(store.restore);
  }

  @override
  void dispose() {
    ads.removeListener(notifyListeners);
    _storeEvents?.cancel();
    _saveTimer?.cancel();
    super.dispose();
  }

  /// Runs OCR on every page of [doc]. Throws a PlatformException if Tesseract fails.
  Future<void> recognize(ScanDocument doc, List<String> codes, {void Function(int page)? onPage}) async {
    await ocr.recognizePages(doc.pages, codes, onPage: onPage);
    doc.languageCodes = codes;
    settings.lastLanguageCodes = codes;
    _changed();
  }

  void setDocumentType(ScanDocument doc, DocType type) {
    doc.type = type;
    _changed();
  }

  void renameDocument(ScanDocument doc, String title) {
    doc.title = title;
    _changed();
  }

  void deleteDocument(ScanDocument doc) {
    documents.remove(doc);
    for (final page in doc.pages) {
      final file = File(page.imagePath);
      if (file.existsSync()) file.deleteSync();
    }
    _changed();
  }

  void addPages(ScanDocument doc, List<ScanPage> pages) {
    doc.pages.addAll(pages);
    _changed();
  }

  void setOnboardingDone(bool value) {
    settings.onboardingDone = value;
    _changed();
  }

  void setThemeMode(ThemeMode mode) {
    settings.themeMode = mode;
    _changed();
  }

  void setDefaultExport(ExportFormat format) {
    settings.defaultExport = format;
    _changed();
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
    settings.lastLanguageCodes.remove(lang.code);
    _changed();
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
