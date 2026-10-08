# polyscan_scanner

The phone's document scanner for Polyscan: VisionKit's document camera on iOS and
Google ML Kit's document scanner on Android. Both find the page edges, crop and
straighten the page on the device, and the plugin returns the pages as JPEG files.

```dart
if (await PolyscanScanner.isAvailable()) {
  final paths = await PolyscanScanner.scan();
}
```

ML Kit's scanner needs Google Play services (it downloads the scanner module once)
and no camera permission. VisionKit is not available on the iOS simulator.
