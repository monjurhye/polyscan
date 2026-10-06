# Risk spike: Tesseract and PDF text (2026-10-06)

The goal was to test the app's two biggest risks without a phone or emulator: (1) the Tesseract OCR plugin, and (2) the `pdf` package's handling of complex scripts.

## Test setup

- Six samples are in `samples.json`: English, Bangla (with conjuncts and Bangla digits), Hindi, Arabic (with Eastern Arabic digits), Thai, and mixed Bangla+English.
- `test/generate_test.dart` renders each sample with Noto fonts into a **clean** image and a **photo-like** image (70% resolution, 1.5° tilt, blur, noise, JPEG quality 45). It also builds two PDFs with `package:pdf`: one with visible text and one searchable PDF (image plus an invisible text layer).
- OCR ran on tesseract.js 7 (the same Tesseract 5 LSTM engine, compiled to WebAssembly). Models: `tessdata_fast` and tesseract.js's `best_int`. Float `tessdata_best` models do not run in the WASM build.
- Accuracy = 1 − character error rate (whitespace removed, NFC normalized).
- Text-layer checks used pypdf and **PDFium**, the PDF engine inside Chrome and Android.

## Result 1: OCR accuracy

| Language | fast clean | fast photo | best_int clean | best_int photo |
|---|---|---|---|---|
| English | 100.0 | 100.0 | 100.0 | 99.2 |
| Bangla | 100.0 | 100.0 | 99.4 | 99.4 |
| Hindi | 98.0 | 97.3 | 98.0 | 96.6 |
| Arabic | 80.2 | 82.9 | 80.2 | 84.7 |
| Thai | 97.3* | 94.6* | 97.3* | 94.6* |
| Bangla+English | 98.3 | 98.3 | 98.3 | 97.4 |

Time per page: 0.25–1 s on a desktop CPU in WASM; a phone will be slower.

\* Thai: almost all the "errors" come from `ำ` being returned as `ํ` + `า`. That is a Unicode normalization difference, fixable with one line of post-processing.

**Important findings:**
- **Bangla is excellent.** The fast model (0.86 MB) read every character correctly. The samples were clean fonts, though; real receipts, old prints and handwriting still need testing.
- **Numbers are a risk.** In Hindi, `16` was read as `6` and `4471229018` as `44722908`. Adding the `hin+eng` model did not fix it. In Arabic, the words were fine but the Eastern Arabic digits (`١٦`, `٢٠٢٦`) came out mostly wrong. Numbers on bills and forms matter most, so this needs a fix: re-read regions that contain digits with the `eng` model plus a digit whitelist, or warn the user.
- **The fast model is enough.** best_int was no better, and the models are about 10× larger (Bangla best: 11 MB vs fast: 0.86 MB).

## Result 2: the `flutter_tesseract_ocr` plugin — not usable

| Problem | Evidence |
|---|---|
| Android **build fails** | Gradle 9 error: `Could not find method jcenter()`, plus a `kotlin-android` plugin error |
| The iOS side depends on **SwiftyTesseract**, archived since 2022 | GitHub: `archived=true`, last push 2022-04-08 |
| iOS reads models only from the app bundle | It tries to create a symlink inside the read-only bundle, so models downloaded later cannot be used |
| iOS has no `extractHocr` (word positions) | Without word positions the searchable PDF's text layer can't be placed correctly |
| iOS hangs on a bad image path | `guard ... else { return }` never calls `result` |
| `assets/tessdata_config.json` is required | Without it, `rootBundle.loadString` crashes |

**Decision:** write our own small plugin.
- **Android:** [Tesseract4Android](https://github.com/adaptech-cz/Tesseract4Android) 4.9.0 (maintained, Tesseract 5). `TessBaseAPI.init(path, lang)` accepts any folder, so on-demand downloads work, and `ResultIterator` gives word positions.
- **iOS:** build Tesseract + Leptonica as an xcframework on Codemagic, or find another maintained build. This is now **the biggest remaining risk** and needs a separate spike.

## Result 3: the `pdf` package with complex scripts

| Language | Visible text (appearance) | Invisible text layer (extracted by PDFium) | PDFium search |
|---|---|---|---|
| English | ✅ | ✅ exact | ✅ |
| Bangla | ❌ vowel signs in the wrong place, conjuncts broken (`দেশের`→`দশেরে`) | ✅ exact | ✅ `বিজ্ঞপ্তি` |
| Hindi | ❌ `ि` in the wrong place, conjuncts broken (`बिजली`→`बजिली`) | ✅ exact | ✅ `स्वास्थ्य` |
| Arabic | ✅ letters join correctly | ⚠️ digits reversed (`١٦`→`٦١`), letters as presentation forms | ✅ `فاتورة` |
| Thai | ✅ (but wrong line breaks inside words) | ✅ exact | ✅ |
| Bangla+English | — | ✅ exact | ✅ |

**Decision:**
- The `pdf` package **can be used for the searchable PDF**. The text layer is invisible, so broken shaping can't be seen, and searching and copying work correctly.
- **Never show visible Bangla or Hindi text in a PDF** from this package (e.g. a "text-only PDF" feature). Create one with native APIs if needed.
- **Arabic:** digits come out reversed in the text layer, so searching for a number fails. Check in real viewers (iOS Files/PDFKit, Adobe). If needed, reverse digit runs before writing the text layer, or build the text layer with native APIs.

## Still unknown
1. Apple Vision on iOS: which languages it reads and how accurately. Run the ArchiveX OCR spike on Codemagic.
2. Tesseract build for iOS (xcframework) and its size.
3. Real documents: receipts, old prints, photos taken by phone. This test used synthetic images.
4. The plugin's speed and memory on a phone.

## Files
- `samples.json`: text and ground truth
- `test/generate_test.dart`: generates images and PDFs (`flutter test test/generate_test.dart`)
- `test/arabic_ltr_test.dart`: Arabic text layer test in LTR order (failed)
- `out/`: generated images, PDFs and renders
- The OCR measurement script (Node, tesseract.js) was kept in a temporary folder; it can be added to the repo if needed
