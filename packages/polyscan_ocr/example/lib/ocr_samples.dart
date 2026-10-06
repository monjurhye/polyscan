import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

/// One bundled test image with its expected text.
class OcrSample {
  const OcrSample(this.asset, this.languages, this.groundTruthKey);

  final String asset;
  final List<String> languages;
  final String groundTruthKey;
}

const ocrSamples = [
  OcrSample('assets/images/eng-clean.png', ['eng'], 'eng'),
  OcrSample('assets/images/ben-clean.png', ['ben'], 'ben'),
  OcrSample('assets/images/ben-photo.jpg', ['ben'], 'ben'),
  OcrSample('assets/images/ben_eng-clean.png', ['ben', 'eng'], 'ben+eng'),
  OcrSample('assets/images/hin-clean.png', ['hin'], 'hin'),
];

class SampleRun {
  SampleRun(this.sample, this.result, this.accuracy, this.elapsed);

  final OcrSample sample;
  final OcrResult result;

  /// 1 − character error rate, whitespace ignored.
  final double accuracy;
  final Duration elapsed;

  @override
  String toString() =>
      '${sample.asset} [${sample.languages.join('+')}] accuracy ${(accuracy * 100).toStringAsFixed(1)}% '
      'conf ${result.meanConfidence} words ${result.words.length} in ${elapsed.inMilliseconds} ms';
}

/// Copies bundled models into a real folder, the way downloaded models will live.
Future<String> prepareTessdata() async {
  final dir = Directory('${Directory.systemTemp.path}/polyscan_ocr_test/tessdata')..createSync(recursive: true);
  for (final lang in ['eng', 'ben', 'hin']) {
    final data = await rootBundle.load('assets/tessdata/$lang.traineddata');
    File('${dir.path}/$lang.traineddata').writeAsBytesSync(data.buffer.asUint8List());
  }
  return dir.path;
}

Future<String> _copyAsset(String asset) async {
  final data = await rootBundle.load(asset);
  final file = File('${Directory.systemTemp.path}/polyscan_ocr_test/${asset.split('/').last}');
  file.writeAsBytesSync(data.buffer.asUint8List());
  return file.path;
}

Future<SampleRun> runSample(OcrSample sample, String tessdataDir, {bool fixDigits = true}) async {
  final truth = (jsonDecode(await rootBundle.loadString('assets/samples.json')) as Map)[sample.groundTruthKey]['text'] as String;
  final path = await _copyAsset(sample.asset);
  final watch = Stopwatch()..start();
  final result = await PolyscanOcr.recognize(
      imagePath: path, tessdataDir: tessdataDir, languages: sample.languages, fixDigits: fixDigits);
  watch.stop();
  return SampleRun(sample, result, accuracy(result.text, truth), watch.elapsed);
}

double accuracy(String actual, String expected) {
  String norm(String s) => s.replaceAll(RegExp(r'\s+'), '');
  final a = norm(actual).runes.toList();
  final b = norm(expected).runes.toList();
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = [i, ...List.filled(b.length, 0)];
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return b.isEmpty ? 1 : 1 - prev[b.length] / b.length;
}
