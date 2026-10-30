import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

import 'data/app_state.dart';
import 'models/document.dart';
import 'screens/document_screen.dart';
import 'screens/home_shell.dart';
import 'screens/languages_screen.dart';
import 'screens/page_viewer_screen.dart';

/// App Store screenshots: before each launch, the ios-screenshots workflow writes
/// the scene name to `Documents/screenshot_scene.txt` in the app's simulator
/// container (simctl doesn't reliably pass environment variables to the app).
/// Sample documents are drawn at launch, so nothing extra ships in the app.
/// Ignored in release builds.
const screenshotScenes = ['documents', 'bangla', 'page', 'arabic', 'languages'];

Future<String?> screenshotScene() async {
  if (kReleaseMode) return null;
  final file = File('${(await getApplicationDocumentsDirectory()).path}/screenshot_scene.txt');
  if (!file.existsSync()) return null;
  final scene = file.readAsStringSync().trim();
  return screenshotScenes.contains(scene) ? scene : null;
}

class _Sample {
  const _Sample(this.title, this.code, this.lines, {this.rtl = false, this.hoursAgo = 0});

  final String title;
  final String code;
  final List<String> lines;
  final bool rtl;
  final int hoursAgo;
}

const _samples = [
  _Sample('ভাড়ার চুক্তিপত্র', 'ben', [
    'ভাড়ার চুক্তিপত্র',
    'বাড়িওয়ালা: মোঃ রহিম উদ্দিন',
    'ভাড়াটিয়া: সুমাইয়া আক্তার',
    'ঠিকানা: ২৪/বি, মিরপুর রোড, ঢাকা',
    'মাসিক ভাড়া: ১৫,০০০ টাকা',
    'চুক্তির মেয়াদ: ১ জানুয়ারি ২০২৭ থেকে এক বছর',
    'প্রতি মাসের ৫ তারিখের মধ্যে ভাড়া পরিশোধ করতে হবে।',
    'বিদ্যুৎ ও গ্যাস বিল ভাড়াটিয়া পরিশোধ করবেন।',
  ]),
  _Sample('Electricity bill October', 'eng', [
    'CITY POWER & LIGHT',
    'Electricity Bill — October 2026',
    'Account number: 4471-2093-118',
    'Billing period: Sep 15 – Oct 14, 2026',
    'Energy used: 312 kWh',
    'Amount due: \$48.70',
    'Due date: November 5, 2026',
    'Pay online, by phone or at any branch.',
  ], hoursAgo: 5),
  _Sample('شهادة إتمام دورة', 'ara', [
    'شهادة إتمام دورة',
    'تشهد إدارة المعهد بأن الطالبة',
    'فاطمة أحمد',
    'قد أتمت بنجاح دورة اللغة الإنجليزية',
    'المستوى: المتوسط',
    'المدة: من سبتمبر إلى ديسمبر ٢٠٢٦',
    'مع تمنياتنا لها بالتوفيق',
  ], rtl: true, hoursAgo: 28),
  _Sample('किराया रसीद', 'hin', [
    'किराया रसीद',
    'प्राप्त किया: श्री अमित शर्मा से',
    'राशि: ₹12,000 (बारह हज़ार रुपये)',
    'अवधि: अक्टूबर 2026',
    'पता: 15, गांधी नगर, जयपुर',
    'भुगतान का तरीका: बैंक ट्रांसफ़र',
    'मकान मालिक के हस्ताक्षर',
  ], hoursAgo: 54),
];

const _fonts = {
  'NotoSans': 'assets/fonts/NotoSans.ttf',
  'NotoSansBengali': 'assets/fonts/NotoSansBengali.ttf',
  'NotoSansDevanagari': 'assets/fonts/NotoSansDevanagari.ttf',
  'NotoSansArabic': 'assets/fonts/NotoSansArabic.ttf',
};

/// Loads sample documents into [state] (in memory only) and returns the screen for [scene].
Future<Widget> prepareScreenshot(AppState state, String scene) async {
  for (final entry in _fonts.entries) {
    await (FontLoader(entry.key)..addFont(rootBundle.load(entry.value))).load();
  }
  final dir = Directory('${(await getTemporaryDirectory()).path}/screenshot');
  dir.createSync(recursive: true);
  final now = DateTime.now();
  final docs = <ScanDocument>[];
  for (var i = 0; i < _samples.length; i++) {
    final s = _samples[i];
    final path = '${dir.path}/sample-$i.png';
    final (width, height) = await _drawPage(s, path);
    docs.add(ScanDocument(
      id: 'sample$i',
      title: s.title,
      createdAt: now.subtract(Duration(hours: s.hoursAgo)),
      languageCodes: [s.code],
      type: DocType.a4,
      pages: [
        ScanPage(imagePath: path)
          ..ocr = OcrResult(
              text: s.lines.join('\n'), meanConfidence: 92, words: const [], imageWidth: width, imageHeight: height),
      ],
    ));
  }
  state.showSamples(docs, readyCodes: const ['ben', 'hin', 'ara', 'spa', 'urd']);

  return switch (scene) {
    'bangla' => DocumentScreen(doc: docs[0], initialTab: 1),
    'page' => PageViewerScreen(doc: docs[1], initialIndex: 0),
    'arabic' => DocumentScreen(doc: docs[2], initialTab: 1),
    'languages' => const LanguagesScreen(),
    _ => const HomeShell(),
  };
}

/// Draws a printed A4 page (150 dpi) with [sample]'s lines and writes it as PNG.
Future<(int, int)> _drawPage(_Sample sample, String path) async {
  const width = 1240, height = 1754, margin = 120.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(const Rect.fromLTWH(0, 0, 1240, 1754), Paint()..color = const Color(0xFFFDFCF8));
  var y = 170.0;
  for (var i = 0; i < sample.lines.length; i++) {
    final heading = i == 0;
    final builder = ui.ParagraphBuilder(ui.ParagraphStyle(
      textDirection: sample.rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: heading ? TextAlign.center : TextAlign.start,
    ))
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF1C1C1C),
        fontSize: heading ? 64 : 40,
        fontWeight: heading ? FontWeight.w700 : FontWeight.w400,
        fontFamily: 'NotoSans',
        fontFamilyFallback: const ['NotoSansBengali', 'NotoSansDevanagari', 'NotoSansArabic'],
      ))
      ..addText(sample.lines[i]);
    final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: width - 2 * margin));
    canvas.drawParagraph(paragraph, Offset(margin, y));
    y += paragraph.height + (heading ? 90 : 46);
    if (heading) {
      canvas.drawLine(Offset(margin, y - 50), Offset(width - margin, y - 50), Paint()
        ..color = const Color(0xFF9AA0A6)
        ..strokeWidth = 3);
    }
  }
  final image = await recorder.endRecording().toImage(width, height);
  final png = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(png!.buffer.asUint8List(), flush: true);
  return (width, height);
}
