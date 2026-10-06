import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/polyscan_ocr_method_channel.dart';
import 'package:polyscan_ocr/polyscan_ocr_platform_interface.dart';

class _FakePlatform with MockPlatformInterfaceMixin implements PolyscanOcrPlatform {
  String? languages;
  Map<String, dynamic>? result;
  List<Map<String, dynamic>> rereads = const [];
  List<List<int>>? askedRegions;
  Map<String, String>? regionVariables;

  @override
  Future<List<Map<String, dynamic>>> recognizeRegions({
    required String imagePath,
    required String tessdataDir,
    required String languages,
    required int pageSegMode,
    required Map<String, String> variables,
    required List<List<int>> regions,
  }) async {
    askedRegions = regions;
    regionVariables = variables;
    return rereads;
  }

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
    this.languages = languages;
    if (result != null) return result!;
    return {
      'text': 'নমস্কার world\n',
      'meanConfidence': 91,
      'words': [
        {'text': 'নমস্কার', 'left': 10, 'top': 20, 'right': 110, 'bottom': 50, 'confidence': 93.5},
        {'text': 'world', 'left': 120, 'top': 20, 'right': 200, 'bottom': 50, 'confidence': 88},
      ],
      'imageWidth': 400,
      'imageHeight': 100,
    };
  }
}

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

    expect(fake.languages, 'ben+eng');
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

  group('digit re-read', () {
    late Directory tessdata;
    late _FakePlatform fake;

    setUp(() {
      tessdata = Directory.systemTemp.createTempSync('tessdata');
      File('${tessdata.path}/eng.traineddata').writeAsStringSync('x');
      fake = _FakePlatform()
        ..result = {
          'text': 'तिथि 6 अक्टूबर\n',
          'meanConfidence': 86,
          'words': [
            {'text': 'तिथि', 'left': 0, 'top': 10, 'right': 50, 'bottom': 50, 'confidence': 90},
            {'text': '6', 'left': 60, 'top': 10, 'right': 100, 'bottom': 50, 'confidence': 70},
            {'text': 'अक्टूबर', 'left': 110, 'top': 10, 'right': 200, 'bottom': 50, 'confidence': 90},
          ],
          'imageWidth': 300,
          'imageHeight': 60,
        }
        ..rereads = [
          {'text': '16', 'confidence': 93.0},
        ];
      PolyscanOcrPlatform.instance = fake;
    });

    tearDown(() => tessdata.deleteSync(recursive: true));

    test('re-reads Latin numbers with eng and a digit whitelist', () async {
      final result = await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin']);

      expect(fake.askedRegions, [
        [52, 0, 108, 60],
      ]);
      expect(fake.regionVariables, {'tessedit_char_whitelist': digitWhitelistForTest});
      expect(result.text, 'तिथि 16 अक्टूबर\n');
      expect(result.words[1].text, '16');
    });

    test('is skipped when turned off, for Latin-only runs, or without eng', () async {
      final off = await PolyscanOcr.recognize(
          imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin'], fixDigits: false);
      expect(off.words[1].text, '6');
      expect(fake.askedRegions, isNull);

      await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['eng']);
      expect(fake.askedRegions, isNull);

      File('${tessdata.path}/eng.traineddata').deleteSync();
      final noEng = await PolyscanOcr.recognize(imagePath: '/x.png', tessdataDir: tessdata.path, languages: ['hin']);
      expect(noEng.words[1].text, '6');
      expect(fake.askedRegions, isNull);
    });
  });
}

const digitWhitelistForTest = '0123456789.,:/-+%()';
