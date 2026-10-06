import 'dart:async';

import 'package:flutter/material.dart';

import '../models/document.dart';
import '../models/ocr_language.dart';
import 'mock_data.dart';

/// In-memory app state. Persistence, purchases and real downloads come later.
class AppState extends ChangeNotifier {
  AppState()
      : documents = MockData.documents(),
        languages = MockData.languages();

  /// Placeholder rule: free users can add this many downloaded languages.
  static const freeDownloadLimit = 2;

  final List<ScanDocument> documents;
  final List<OcrLanguage> languages;
  final Map<String, double> downloadProgress = {};

  bool isPro = false;
  bool onboardingDone = false;
  ThemeMode themeMode = ThemeMode.system;
  ExportFormat defaultExport = ExportFormat.pdf;
  List<String> lastLanguageCodes = ['eng'];

  int _nextId = 100;

  List<OcrLanguage> get readyLanguages => languages.where((l) => l.isReady).toList();

  int get downloadedCount =>
      languages.where((l) => l.status == LanguageStatus.downloaded).length;

  bool get canDownloadMore => isPro || downloadedCount < freeDownloadLimit;

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
      recognizedText: codes.isEmpty ? null : MockData.sampleText(codes),
    );
    documents.insert(0, doc);
    if (codes.isNotEmpty) lastLanguageCodes = codes;
    notifyListeners();
    return doc;
  }

  void recognize(ScanDocument doc, List<String> codes) {
    doc.languageCodes = codes;
    doc.recognizedText = MockData.sampleText(codes);
    lastLanguageCodes = codes;
    notifyListeners();
  }

  void renameDocument(ScanDocument doc, String title) {
    doc.title = title;
    notifyListeners();
  }

  void deleteDocument(ScanDocument doc) {
    documents.remove(doc);
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

  /// Simulates a model download so the progress UI can be reviewed.
  void downloadLanguage(OcrLanguage lang) {
    if (downloadProgress.containsKey(lang.code)) return;
    downloadProgress[lang.code] = 0;
    notifyListeners();
    Timer.periodic(const Duration(milliseconds: 120), (timer) {
      final next = (downloadProgress[lang.code] ?? 0) + 0.08;
      if (next >= 1) {
        timer.cancel();
        downloadProgress.remove(lang.code);
        lang.status = LanguageStatus.downloaded;
      } else {
        downloadProgress[lang.code] = next;
      }
      notifyListeners();
    });
  }

  void removeLanguage(OcrLanguage lang) {
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
