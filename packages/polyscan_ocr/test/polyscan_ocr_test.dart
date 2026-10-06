import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';
import 'package:polyscan_ocr/polyscan_ocr_method_channel.dart';
import 'package:polyscan_ocr/polyscan_ocr_platform_interface.dart';

class _FakePlatform with MockPlatformInterfaceMixin implements PolyscanOcrPlatform {
  String? languages;

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
}
