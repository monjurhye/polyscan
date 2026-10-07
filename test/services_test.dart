import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pdf/widgets.dart' as pw;
import 'package:polyscan/models/document.dart';
import 'package:polyscan/services/exporter.dart';
import 'package:polyscan/services/model_store.dart';
import 'package:polyscan/services/page_renderer.dart';
import 'package:polyscan/services/pdf_builder.dart';
import 'package:polyscan_ocr/polyscan_ocr.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('polyscan_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  String writeImage(int width, int height, {String name = 'page.png'}) {
    final image = img.Image(width: width, height: height)..clear(img.ColorRgb8(255, 255, 255));
    img.fillRect(image, x1: 10, y1: 10, x2: 60, y2: 30, color: img.ColorRgb8(200, 30, 30));
    final path = '${tmp.path}/$name';
    File(path).writeAsBytesSync(img.encodePng(image));
    return path;
  }

  group('PageRenderer', () {
    test('rotation swaps width and height', () {
      final out = '${tmp.path}/out.jpg';
      PageRenderer.renderFile(writeImage(400, 200), out, PageFilter.original, 1);
      final result = img.decodeJpg(File(out).readAsBytesSync())!;
      expect([result.width, result.height], [200, 400]);
    });

    test('large images are scaled down to maxSide', () {
      final out = '${tmp.path}/out.jpg';
      PageRenderer.renderFile(writeImage(4000, 1000), out, PageFilter.color, 0);
      final result = img.decodeJpg(File(out).readAsBytesSync())!;
      expect([result.width, result.height], [PageRenderer.maxSide, 750]);
    });

    test('black & white leaves only black and white pixels', () {
      final out = '${tmp.path}/out.png';
      final source = img.decodePng(File(writeImage(100, 50)).readAsBytesSync())!;
      final bw = PageRenderer.applyFilter(source, PageFilter.blackWhite);
      File(out).writeAsBytesSync(img.encodePng(bw));
      final levels = {for (final p in bw) p.r.toInt()};
      expect(levels.difference({0, 255}), isEmpty);
    });

    test('renders are cached per filter and rotation', () async {
      final renderer = PageRenderer(cacheDir: () async => tmp);
      final page = ScanPage(imagePath: writeImage(300, 300));
      final first = await renderer.render(page);
      expect(await renderer.render(page), first);
      page.quarterTurns = 1;
      expect(await renderer.render(page), isNot(first));
    });

    test('a file that is not an image throws FormatException', () {
      final bad = File('${tmp.path}/bad.jpg')..writeAsStringSync('not an image');
      expect(() => PageRenderer.renderFile(bad.path, '${tmp.path}/o.jpg', PageFilter.original, 0),
          throwsFormatException);
    });
  });

  group('PdfBuilder', () {
    final fonts = [
      for (final f in PdfBuilder.fontAssets) pw.Font.ttf(File(f).readAsBytesSync().buffer.asByteData()),
    ];

    test('builds one page per image, sized to the image aspect ratio', () async {
      final ocr = OcrResult(
        text: 'Hello বাংলা',
        meanConfidence: 90,
        imageWidth: 1000,
        imageHeight: 1414,
        words: const [
          OcrWord(text: 'Hello', left: 100, top: 100, right: 300, bottom: 140, confidence: 95),
          OcrWord(text: 'বাংলা', left: 320, top: 100, right: 500, bottom: 140, confidence: 90),
          OcrWord(text: 'हिन्दी', left: 100, top: 200, right: 300, bottom: 240, confidence: 90),
        ],
      );
      final pages = [
        PdfPageInput(writeImage(1000, 1414, name: 'a.png'), ocr),
        PdfPageInput(writeImage(800, 400, name: 'b.png'), null),
      ];
      final bytes = await PdfBuilder(fonts: () async => fonts).build(pages, title: 'Test');
      final pdf = String.fromCharCodes(bytes);
      expect(pdf, startsWith('%PDF'));
      expect(RegExp(r'/Type\s*/Page\b').allMatches(pdf).length, 2);
      // Second page: 800x400 image → 595 x 297.5 points.
      expect(pdf, contains('297.5'));
      File('${tmp.path}/../polyscan_test_out.pdf').writeAsBytesSync(bytes);
    });
  });

  group('ModelStore', () {
    late HttpServer server;
    late ModelStore store;
    final model = List<int>.generate(300000, (i) => i % 251);

    setUp(() async {
      // flutter_test answers every HttpClient request with 400; talk to the local server for real.
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((req) {
        if (req.uri.path.endsWith('/ben.traineddata')) {
          req.response
            ..contentLength = model.length
            ..add(model);
        } else {
          req.response.statusCode = HttpStatus.notFound;
        }
        req.response.close();
      });
      store = ModelStore(
        baseDir: () async => tmp,
        source: 'http://${server.address.host}:${server.port}/tessdata_fast',
      );
    });
    tearDown(() => server.close(force: true));

    test('copies the bundled English model into a folder named tessdata', () async {
      final dir = await store.directory();
      expect(dir.uri.pathSegments.where((s) => s.isNotEmpty).last, 'tessdata');
      expect(File('${dir.path}/eng.traineddata').lengthSync(), greaterThan(1000000));
      expect(await store.installed(), {'eng'});
    });

    test('downloads a model with progress, then removes it', () async {
      final progress = <double>[];
      await store.download('ben', onProgress: progress.add);
      expect(progress.last, 1.0);
      expect(await store.installed(), {'eng', 'ben'});
      expect(File('${(await store.directory()).path}/ben.traineddata').readAsBytesSync(), model);

      await store.remove('ben');
      await store.remove('eng'); // bundled: kept
      expect(await store.installed(), {'eng'});
    });

    test('a failed download leaves nothing behind', () async {
      await expectLater(store.download('xyz'), throwsA(isA<ModelDownloadException>()));
      final names = (await store.directory()).listSync().map((f) => f.uri.pathSegments.last);
      expect(names, ['eng.traineddata']);
    });
  });

  test('export file names keep every script and drop unsafe characters', () {
    expect(Exporter.fileName('বিদ্যুৎ বিল: সেপ্টেম্বর/2026?'), 'বিদ্যুৎ বিল সেপ্টেম্বর2026');
    expect(Exporter.fileName('  <>  '), 'Polyscan');
  });
}
