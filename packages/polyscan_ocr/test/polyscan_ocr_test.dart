import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/polyscan_ocr_method_channel.dart';
import 'package:polyscan_ocr/polyscan_ocr_platform_interface.dart';

class _FakePlatform with MockPlatformInterfaceMixin implements PolyscanOcrPlatform {
  /// Result per language string; [defaultResult] for anything else.
  final Map<String, Map<String, dynamic>> results = {};
  final List<String> calls = [];

  static const defaultResult = <String, dynamic>{
    'text': 'নমস্কার world\n',
    'meanConfidence': 91,
    'words': [
      {'text': 'নমস্কার', 'left': 10, 'top': 20, 'right': 110, 'bottom': 50, 'confidence': 93.5},
      {'text': 'world', 'left': 120, 'top': 20, 'right': 200, 'bottom': 50, 'confidence': 88},
    ],
    'imageWidth': 400,
    'imageHeight': 100,
  };

  /// What the system OCR returns; null means "can't read these languages".
  Map<String, dynamic>? systemResult;
  final List<List<String>> systemCalls = [];

  @override
  Future<Map<String, dynamic>?> recognizeSystem({required String imagePath, required List<String> languages}) async {
    systemCalls.add(languages);
    return systemResult;
  }

  @override
  Future<String> tesseractVersion() async => '5.5.3';

  final List<int> modes = [];

  @override
  Future<Map<String, dynamic>> recognize({
    required String imagePath,
    required String tessdataDir,
    required String languages,
    required int pageSegMode,
    required Map<String, String> variables,
  }) async {
    calls.add(languages);
    modes.add(pageSegMode);
    return results[languages] ?? defaultResult;
  }
}

Map<String, dynamic> _result(String text, List<(String, int, int, double)> words) => {
      'text': text,
      'meanConfidence': 86,
      'words': [
        for (final (t, l, r, c) in words) {'text': t, 'left': l, 'top': 10, 'right': r, 'bottom': 50, 'confidence': c},
      ],
      'imageWidth': 300,
      'imageHeight': 60,
    };

void main() {
  test('default platform is the method channel', () {
    expect(PolyscanOcrPlatform.instance, isA<MethodChannelPolyscanOcr>());
  });

  test('recognize joins languages and parses words', () async {
    final fake = _FakePlatform();
    PolyscanOcrPlatform.instance = fake;

    final result = await PolyscanOcr.recognize(
      imagePath: '/x.png',
      tessdataDir: '/tessdata',
      languages: ['ben', 'eng'],
    );

    expect(fake.calls.first, 'ben+eng');
    expect(result.meanConfidence, 91);
    expect(result.words, hasLength(2));
    expect(result.words.first.text, 'নমস্কার');
    expect(result.words.last.confidence, 88.0);
    expect(result.imageWidth, 400);
  });

  test('recognize rejects an empty language list', () {
    expect(
      () => PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: '/t', languages: []),
      throwsArgumentError,
    );
  });

  group('digit fix', () {
    late Directory tessdata;
    late _FakePlatform fake;

    setUp(() {
      tessdata = Directory.systemTemp.createTempSync('tessdata');
      File('${tessdata.path}/eng.traineddata').writeAsStringSync('x');
      fake = _FakePlatform();
      fake.results['hin'] = _result('तिथि 6 अक्टूबर\n', [
        ('तिथि', 0, 50, 90),
        ('6', 75, 100, 0),
        ('अक्टूबर', 110, 200, 90),
      ]);
      fake.results['eng'] = _result('fefer 16 3teapar\n', [
        ('fefer', 0, 50, 40),
        ('16', 60, 100, 93),
        ('3teapar', 110, 200, 30),
      ]);
      PolyscanOcrPlatform.instance = fake;
    });

    tearDown(() => tessdata.deleteSync(recursive: true));

    test('a second eng pass fixes numbers the main model got wrong', () async {
      final result = await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin']);

      expect(fake.calls, ['hin', 'eng']);
      expect(result.text, 'तिथि 16 अक्टूबर\n');
      expect(result.words[1].text, '16');
    });

    test('is skipped when turned off, for Latin-only runs, without digits, or without eng', () async {
      final off = await PolyscanOcr.recognize(
          imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin'], fixDigits: false);
      expect(off.words[1].text, '6');

      await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['eng']);

      fake.results['ben'] = _result('নমস্কার\n', [('নমস্কার', 0, 80, 90)]);
      await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['ben']);

      File('${tessdata.path}/eng.traineddata').deleteSync();
      final noEng = await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin']);
      expect(noEng.words[1].text, '6');

      expect(fake.calls, ['hin', 'eng', 'ben', 'hin']);
    });
  });

  group('system OCR on iOS', () {
    tearDown(() => PolyscanOcr.debugOnIOS = null);

    test('Vision result is used when it reads the languages', () async {
      final fake = _FakePlatform()
        ..systemResult = {..._result('Invoice 4471\n', [('Invoice', 0, 100, 97), ('4471', 110, 160, 97)]), 'engine': 'vision'};
      PolyscanOcrPlatform.instance = fake;
      PolyscanOcr.debugOnIOS = true;

      final result = await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['eng']);
      expect(result.engine, 'vision');
      expect(result.text, 'Invoice 4471\n');
      expect(fake.systemCalls, [['eng']]);
      expect(fake.calls, isEmpty, reason: 'Tesseract must not run');
    });

    test('falls back to Tesseract when Vision cannot read a language', () async {
      final fake = _FakePlatform(); // systemResult stays null
      PolyscanOcrPlatform.instance = fake;
      PolyscanOcr.debugOnIOS = true;

      final result = await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['ben', 'eng']);
      expect(result.engine, 'tesseract');
      expect(fake.systemCalls, [['ben', 'eng']]);
      expect(fake.calls, ['ben+eng']);
    });

    test('preferSystem: false and other platforms skip Vision', () async {
      final fake = _FakePlatform()..systemResult = {..._FakePlatform.defaultResult, 'engine': 'vision'};
      PolyscanOcrPlatform.instance = fake;

      PolyscanOcr.debugOnIOS = true;
      await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['eng'], preferSystem: false);
      PolyscanOcr.debugOnIOS = false;
      await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['eng']);
      expect(fake.systemCalls, isEmpty);
      expect(fake.calls, ['eng', 'eng']);
    });
  });

  test('vertical CJK models read in vertical block mode', () async {
    final fake = _FakePlatform();
    PolyscanOcrPlatform.instance = fake;
    await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['jpn_vert']);
    await PolyscanOcr.recognize(imagePath: 'p.png', tessdataDir: '/t', languages: ['jpn']);
    await PolyscanOcr.recognize(
        imagePath: 'p.png', tessdataDir: '/t', languages: ['jpn_vert'], pageSegMode: PageSegMode.singleLine);
    expect(fake.modes, [PageSegMode.singleBlockVertical, PageSegMode.auto, PageSegMode.singleLine]);
  });
}
