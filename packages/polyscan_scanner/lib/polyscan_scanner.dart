import 'package:flutter/services.dart';

/// The phone's built-in document scanner: VisionKit's document camera on iOS,
/// Google ML Kit's document scanner on Android. Both find the page edges,
/// crop and straighten it, and run on the device.
class PolyscanScanner {
  const PolyscanScanner._();

  static const _channel = MethodChannel('polyscan_scanner');

  /// Whether a scanner can be shown on this device (false on the iOS
  /// simulator, or on Android phones without Google Play services).
  static Future<bool> isAvailable() async => await _channel.invokeMethod<bool>('isAvailable') ?? false;

  /// Opens the scanner and returns the paths of the scanned page images
  /// (JPEG, in the app's cache folder), in order. Empty if the user cancelled.
  ///
  /// [pageLimit] caps the pages per scan on Android; iOS has no limit.
  ///
  /// Throws a [PlatformException] with code `unavailable` when there is no
  /// scanner, `busy` if one is already open, or `scan_failed`.
  static Future<List<String>> scan({int pageLimit = 50}) async {
    final paths = await _channel.invokeListMethod<String>('scan', {'pageLimit': pageLimit});
    return paths ?? const [];
  }
}
