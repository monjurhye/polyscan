import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Where Tesseract models live on the phone, and how they get there.
///
/// English is bundled as an asset and copied out on first use; every other
/// language is a tessdata_fast model downloaded once, then used offline.
class ModelStore {
  ModelStore({HttpClient? http, Future<Directory> Function()? baseDir, this.source = defaultSource})
      : _http = http ?? HttpClient(),
        _baseDir = baseDir ?? getApplicationSupportDirectory;

  static const bundled = {'eng'};
  static const defaultSource = 'https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main';

  /// Base URL the `<code>.traineddata` files are downloaded from.
  final String source;
  final HttpClient _http;
  final Future<Directory> Function() _baseDir;
  Directory? _dir;

  /// The folder handed to Tesseract. It must be named `tessdata` (Android requires it).
  Future<Directory> directory() async {
    if (_dir != null) return _dir!;
    final dir = Directory('${(await _baseDir()).path}/tessdata');
    await dir.create(recursive: true);
    for (final code in bundled) {
      final file = File('${dir.path}/$code.traineddata');
      if (!file.existsSync()) {
        final data = await rootBundle.load('assets/tessdata/$code.traineddata');
        await file.writeAsBytes(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes), flush: true);
      }
    }
    return _dir = dir;
  }

  /// Codes of every model on the phone, bundled ones included.
  Future<Set<String>> installed() async {
    final dir = await directory();
    return {
      for (final f in dir.listSync().whereType<File>())
        if (f.path.endsWith('.traineddata')) f.uri.pathSegments.last.replaceAll('.traineddata', ''),
    };
  }

  /// Downloads `<code>.traineddata`, reporting progress from 0 to 1.
  /// Writes to a `.part` file first so a broken download never looks installed.
  Future<void> download(String code, {void Function(double progress)? onProgress}) async {
    final dir = await directory();
    final target = File('${dir.path}/$code.traineddata');
    final part = File('${target.path}.part');
    final request = await _http.getUrl(Uri.parse('$source/$code.traineddata'));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw ModelDownloadException(code, 'HTTP ${response.statusCode}');
    }
    final total = response.contentLength;
    var received = 0;
    final sink = part.openWrite();
    try {
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.flush();
    } catch (e) {
      await sink.close();
      if (part.existsSync()) await part.delete();
      throw ModelDownloadException(code, '$e');
    }
    await sink.close();
    if (total > 0 && received != total) {
      await part.delete();
      throw ModelDownloadException(code, 'incomplete ($received of $total bytes)');
    }
    await part.rename(target.path);
  }

  Future<void> remove(String code) async {
    if (bundled.contains(code)) return;
    final file = File('${(await directory()).path}/$code.traineddata');
    if (file.existsSync()) await file.delete();
  }
}

class ModelDownloadException implements Exception {
  ModelDownloadException(this.code, this.reason);

  final String code;
  final String reason;

  @override
  String toString() => 'Could not download $code: $reason';
}
