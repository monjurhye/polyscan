import 'dart:math';

import '../models/document.dart';
import '../models/ocr_language.dart';

/// Demo content so the UI can be built and reviewed before scanning and OCR exist.
class MockData {
  static final _random = Random();

  static List<ScanDocument> documents() {
    final now = DateTime.now();
    return [
      ScanDocument(
        id: 'd1',
        title: 'Rental agreement',
        createdAt: now.subtract(const Duration(hours: 3)),
        pages: [ScanPage(seed: 11), ScanPage(seed: 12), ScanPage(seed: 13)],
        languageCodes: ['eng'],
        recognizedText: _english,
      ),
      ScanDocument(
        id: 'd2',
        title: 'Electricity bill – September',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        pages: [ScanPage(seed: 21, filter: PageFilter.grayscale)],
        languageCodes: ['eng', 'hin'],
        recognizedText: _hindi,
      ),
      ScanDocument(
        id: 'd3',
        title: 'Passport copy',
        createdAt: now.subtract(const Duration(days: 4)),
        pages: [ScanPage(seed: 31), ScanPage(seed: 32)],
      ),
      ScanDocument(
        id: 'd4',
        title: 'Apuntes de clase – Tema 4',
        createdAt: now.subtract(const Duration(days: 12)),
        pages: [
          ScanPage(seed: 41, filter: PageFilter.blackWhite),
          ScanPage(seed: 42, filter: PageFilter.blackWhite),
          ScanPage(seed: 43, filter: PageFilter.blackWhite),
          ScanPage(seed: 44, filter: PageFilter.blackWhite),
        ],
        languageCodes: ['spa'],
        recognizedText: _spanish,
      ),
    ];
  }

  // Sizes are placeholders; replace with the real tessdata_fast model sizes.
  static List<OcrLanguage> languages() => [
        OcrLanguage(code: 'eng', name: 'English', nativeName: 'English', sizeMb: 4.1, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'spa', name: 'Spanish', nativeName: 'Español', sizeMb: 2.2, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'fra', name: 'French', nativeName: 'Français', sizeMb: 1.1, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'deu', name: 'German', nativeName: 'Deutsch', sizeMb: 1.5, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'por', name: 'Portuguese', nativeName: 'Português', sizeMb: 1.9, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'ita', name: 'Italian', nativeName: 'Italiano', sizeMb: 2.6, status: LanguageStatus.builtIn),
        OcrLanguage(code: 'hin', name: 'Hindi', nativeName: 'हिन्दी', sizeMb: 1.0, status: LanguageStatus.downloaded),
        OcrLanguage(code: 'ben', name: 'Bengali', nativeName: 'বাংলা', sizeMb: 0.9),
        OcrLanguage(code: 'ara', name: 'Arabic', nativeName: 'العربية', sizeMb: 1.4),
        OcrLanguage(code: 'ind', name: 'Indonesian', nativeName: 'Bahasa Indonesia', sizeMb: 1.2),
        OcrLanguage(code: 'tha', name: 'Thai', nativeName: 'ไทย', sizeMb: 1.0),
        OcrLanguage(code: 'rus', name: 'Russian', nativeName: 'Русский', sizeMb: 3.6),
        OcrLanguage(code: 'urd', name: 'Urdu', nativeName: 'اردو', sizeMb: 1.1),
        OcrLanguage(code: 'tam', name: 'Tamil', nativeName: 'தமிழ்', sizeMb: 0.8),
        OcrLanguage(code: 'tel', name: 'Telugu', nativeName: 'తెలుగు', sizeMb: 0.9),
        OcrLanguage(code: 'mar', name: 'Marathi', nativeName: 'मराठी', sizeMb: 1.0),
        OcrLanguage(code: 'guj', name: 'Gujarati', nativeName: 'ગુજરાતી', sizeMb: 0.8),
        OcrLanguage(code: 'pan', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', sizeMb: 0.8),
        OcrLanguage(code: 'nep', name: 'Nepali', nativeName: 'नेपाली', sizeMb: 0.9),
        OcrLanguage(code: 'fas', name: 'Persian', nativeName: 'فارسی', sizeMb: 0.9),
        OcrLanguage(code: 'tur', name: 'Turkish', nativeName: 'Türkçe', sizeMb: 1.8),
        OcrLanguage(code: 'vie', name: 'Vietnamese', nativeName: 'Tiếng Việt', sizeMb: 0.9),
        OcrLanguage(code: 'msa', name: 'Malay', nativeName: 'Bahasa Melayu', sizeMb: 1.1),
        OcrLanguage(code: 'fil', name: 'Filipino', nativeName: 'Filipino', sizeMb: 0.9),
        OcrLanguage(code: 'swa', name: 'Swahili', nativeName: 'Kiswahili', sizeMb: 0.8),
        OcrLanguage(code: 'jpn', name: 'Japanese', nativeName: '日本語', sizeMb: 2.4),
        OcrLanguage(code: 'kor', name: 'Korean', nativeName: '한국어', sizeMb: 1.6),
        OcrLanguage(code: 'chi_sim', name: 'Chinese (Simplified)', nativeName: '简体中文', sizeMb: 2.4),
      ];

  static List<ScanPage> newPages(int count) =>
      List.generate(count, (_) => ScanPage(seed: _random.nextInt(1 << 20)));

  static String sampleText(List<String> codes) {
    if (codes.contains('hin')) return _hindi;
    if (codes.contains('spa')) return _spanish;
    return _english;
  }

  static const _english = '''RESIDENTIAL TENANCY AGREEMENT

This agreement is made on 1 October 2026 between the Landlord and the Tenant named below.

1. Premises. The Landlord agrees to rent to the Tenant the apartment at Flat 4B, 12 Green Road.

2. Term. The tenancy begins on 1 October 2026 and continues for twelve (12) months.

3. Rent. The monthly rent is payable in advance on or before the 5th day of each month.

4. Deposit. A security deposit equal to two months' rent is payable on signing.''';

  static const _hindi = '''बिजली बिल – सितंबर 2026

उपभोक्ता संख्या: 4471 2290 18
बिल की तारीख: 02/10/2026
देय तिथि: 16/10/2026

पिछली रीडिंग: 18,204
वर्तमान रीडिंग: 18,437
खपत: 233 यूनिट

Total amount due: ₹ 1,684.00''';

  static const _spanish = '''Tema 4: La célula

La célula es la unidad básica de la vida. Todos los seres vivos están formados por una o más células.

Partes principales:
• Membrana plasmática
• Citoplasma
• Núcleo

Las células procariotas no tienen núcleo definido; las eucariotas sí.''';
}
