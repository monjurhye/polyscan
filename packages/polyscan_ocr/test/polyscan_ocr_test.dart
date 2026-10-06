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

  @override
  Future<String> tesseractVersion() async => '5.5.3';

  @override
  Future<Map<String, dynamic>> recognize({
    required String imagePath,
    required String tessdataDir,
    required String languages,
    required int pageSegMode,
    required Map<String, String> variables,
  }) async {
    calls.add(languages);
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
}
