import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:polyscan_scanner/polyscan_scanner.dart';

import '../models/document.dart';

/// Gets page images from the camera, Photos or Files and copies them into the
/// app's own folder, so a scan survives the original being deleted.
class PageImporter {
  PageImporter({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;
  int _counter = 0;

  /// Returns the new pages, or an empty list if the user cancelled.
  Future<List<ScanPage>> pick(ScanSource source) async {
    // imageQuality makes image_picker re-encode as JPEG; iPhone photos are often HEIC,
    // which package:image can't decode.
    const quality = 92;
    final paths = switch (source) {
      ScanSource.camera => await _scanOrPhoto(quality),
      ScanSource.photos => [for (final x in await _picker.pickMultiImage(imageQuality: quality)) x.path],
      ScanSource.files => [
          for (final f in await FilePicker.pickFiles(type: FileType.image))
            if (f.path != null) f.path!,
        ],
    };
    return [for (final p in paths) ScanPage(imagePath: await _keep(p))];
  }

  /// The phone's document scanner (edge detection, crop, several pages); a plain
  /// camera photo where there is none (iOS simulator, Android without Play services).
  Future<List<String>> _scanOrPhoto(int quality) async {
    if (await _scannerAvailable()) {
      try {
        return await PolyscanScanner.scan();
      } on PlatformException catch (e) {
        if (e.code != 'unavailable') rethrow;
      }
    }
    final photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: quality);
    return [if (photo != null) photo.path];
  }

  Future<bool> _scannerAvailable() async {
    try {
      return await PolyscanScanner.isAvailable();
    } on MissingPluginException {
      return false;
    }
  }

  Future<String> _keep(String path) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pages')..createSync(recursive: true);
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
    final name = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}.$ext';
    return (await File(path).copy('${dir.path}/$name')).path;
  }
}
