import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

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
      // Plain camera photo until the edge-detecting document scanner is wired in.
      ScanSource.camera => [
          if (await _picker.pickImage(source: ImageSource.camera, imageQuality: quality) case final x?) x.path,
        ],
      ScanSource.photos => [for (final x in await _picker.pickMultiImage(imageQuality: quality)) x.path],
      ScanSource.files => [
          for (final f in await FilePicker.pickFiles(type: FileType.image))
            if (f.path != null) f.path!,
        ],
    };
    return [for (final p in paths) ScanPage(imagePath: await _keep(p))];
  }

  Future<String> _keep(String path) async {
    final dir = Directory('${(await getApplicationDocumentsDirectory()).path}/pages')..createSync(recursive: true);
    final ext = path.contains('.') ? path.split('.').last.toLowerCase() : 'jpg';
    final name = '${DateTime.now().microsecondsSinceEpoch}-${_counter++}.$ext';
    return (await File(path).copy('${dir.path}/$name')).path;
  }
}
