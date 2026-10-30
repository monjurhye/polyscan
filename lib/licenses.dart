import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Adds licenses for code and data that don't come from Dart packages, so they
/// show on the Open-source licenses page next to the packages' own.
void registerLicenses() {
  LicenseRegistry.addLicense(() async* {
    final apache = await rootBundle.loadString('assets/licenses/apache-2.0.txt');
    final leptonica = await rootBundle.loadString('assets/licenses/leptonica.txt');
    final ofl = await rootBundle.loadString('assets/licenses/ofl-1.1.txt');
    yield LicenseEntryWithLineBreaks(['Tesseract OCR'], 'Copyright Google and the Tesseract contributors.\n\n$apache');
    yield LicenseEntryWithLineBreaks(
        ['Tesseract language models (tessdata)'], 'Copyright Google and the Tesseract contributors.\n\n$apache');
    if (defaultTargetPlatform == TargetPlatform.android) {
      yield LicenseEntryWithLineBreaks(['Tesseract4Android'], 'Copyright Robert Pösel and contributors.\n\n$apache');
    }
    yield LicenseEntryWithLineBreaks(['Leptonica'], leptonica);
    yield LicenseEntryWithLineBreaks(['Noto Sans fonts'], ofl);
  });
}
