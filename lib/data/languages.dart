import '../models/ocr_language.dart';

/// Languages offered for OCR. English ships with the app; the rest are tessdata_fast
/// models downloaded on demand. Sizes are the tessdata_fast file sizes (checked 2026-10-07).
List<OcrLanguage> languageCatalog() => [
      OcrLanguage(code: 'eng', name: 'English', nativeName: 'English', sizeMb: 3.9, status: LanguageStatus.builtIn),
      OcrLanguage(code: 'spa', name: 'Spanish', nativeName: 'Español', sizeMb: 2.2, free: true),
      OcrLanguage(code: 'fra', name: 'French', nativeName: 'Français', sizeMb: 1.1, free: true),
      OcrLanguage(code: 'deu', name: 'German', nativeName: 'Deutsch', sizeMb: 1.5, free: true),
      OcrLanguage(code: 'por', name: 'Portuguese', nativeName: 'Português', sizeMb: 1.9, free: true),
      OcrLanguage(code: 'ita', name: 'Italian', nativeName: 'Italiano', sizeMb: 2.6, free: true),
      OcrLanguage(code: 'hin', name: 'Hindi', nativeName: 'हिन्दी', sizeMb: 1.1),
      OcrLanguage(code: 'ben', name: 'Bengali', nativeName: 'বাংলা', sizeMb: 0.8),
      OcrLanguage(code: 'ara', name: 'Arabic', nativeName: 'العربية', sizeMb: 1.4),
      OcrLanguage(code: 'ind', name: 'Indonesian', nativeName: 'Bahasa Indonesia', sizeMb: 1.1),
      OcrLanguage(code: 'tha', name: 'Thai', nativeName: 'ไทย', sizeMb: 1.0),
      OcrLanguage(code: 'rus', name: 'Russian', nativeName: 'Русский', sizeMb: 3.7),
      OcrLanguage(code: 'urd', name: 'Urdu', nativeName: 'اردو', sizeMb: 1.3),
      OcrLanguage(code: 'tam', name: 'Tamil', nativeName: 'தமிழ்', sizeMb: 3.1),
      OcrLanguage(code: 'tel', name: 'Telugu', nativeName: 'తెలుగు', sizeMb: 2.6),
      OcrLanguage(code: 'mar', name: 'Marathi', nativeName: 'मराठी', sizeMb: 2.0),
      OcrLanguage(code: 'guj', name: 'Gujarati', nativeName: 'ગુજરાતી', sizeMb: 1.4),
      OcrLanguage(code: 'pan', name: 'Punjabi', nativeName: 'ਪੰਜਾਬੀ', sizeMb: 0.5),
      OcrLanguage(code: 'nep', name: 'Nepali', nativeName: 'नेपाली', sizeMb: 1.0),
      OcrLanguage(code: 'fas', name: 'Persian', nativeName: 'فارسی', sizeMb: 0.4),
      OcrLanguage(code: 'tur', name: 'Turkish', nativeName: 'Türkçe', sizeMb: 4.3),
      OcrLanguage(code: 'vie', name: 'Vietnamese', nativeName: 'Tiếng Việt', sizeMb: 0.5),
      OcrLanguage(code: 'msa', name: 'Malay', nativeName: 'Bahasa Melayu', sizeMb: 1.7),
      OcrLanguage(code: 'fil', name: 'Filipino', nativeName: 'Filipino', sizeMb: 1.8),
      OcrLanguage(code: 'swa', name: 'Swahili', nativeName: 'Kiswahili', sizeMb: 2.1),
      OcrLanguage(code: 'jpn', name: 'Japanese', nativeName: '日本語', sizeMb: 2.4),
      OcrLanguage(code: 'kor', name: 'Korean', nativeName: '한국어', sizeMb: 1.6),
      OcrLanguage(code: 'chi_sim', name: 'Chinese (Simplified)', nativeName: '简体中文', sizeMb: 2.4),
    ];
