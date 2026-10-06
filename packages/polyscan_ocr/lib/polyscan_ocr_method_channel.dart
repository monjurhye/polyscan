import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'polyscan_ocr_platform_interface.dart';

class MethodChannelPolyscanOcr extends PolyscanOcrPlatform {
  @visibleForTesting
  final methodChannel = const MethodChannel('polyscan_ocr');

  @override
  Future<String> tesseractVersion() async {
    return (await methodChannel.invokeMethod<String>('tesseractVersion'))!;
  }

  @override
  Future<Map<String, dynamic>> recognize({
    required String imagePath,
    required String tessdataDir,
    required String languages,
    required int pageSegMode,
    required Map<String, String> variables,
  }) async {
    final result = await methodChannel.invokeMapMethod<String, dynamic>('recognize', {
      'imagePath': imagePath,
      'tessdataDir': tessdataDir,
      'languages': languages,
      'pageSegMode': pageSegMode,
      'variables': variables,
    });
    return result!;
  }
}
