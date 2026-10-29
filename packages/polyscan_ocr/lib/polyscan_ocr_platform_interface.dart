import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'polyscan_ocr_method_channel.dart';

abstract class PolyscanOcrPlatform extends PlatformInterface {
  PolyscanOcrPlatform() : super(token: _token);

  static final Object _token = Object();

  static PolyscanOcrPlatform _instance = MethodChannelPolyscanOcr();

  static PolyscanOcrPlatform get instance => _instance;

  static set instance(PolyscanOcrPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String> tesseractVersion() {
    throw UnimplementedError('tesseractVersion() has not been implemented.');
  }

  /// Returns the raw result map produced by the native side.
  Future<Map<String, dynamic>> recognize({
    required String imagePath,
    required String tessdataDir,
    required String languages,
    required int pageSegMode,
    required Map<String, String> variables,
  }) {
    throw UnimplementedError('recognize() has not been implemented.');
  }

  /// Reads the image with the system's own OCR (Apple Vision on iOS). Returns null
  /// when the system can't read all of [languages] (Tesseract codes), or on Android.
  Future<Map<String, dynamic>?> recognizeSystem({
    required String imagePath,
    required List<String> languages,
  }) async =>
      null;
}
