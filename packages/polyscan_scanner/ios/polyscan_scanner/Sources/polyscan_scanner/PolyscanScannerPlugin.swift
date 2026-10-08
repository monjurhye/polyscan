import Flutter
import UIKit
import VisionKit

/// Presents VisionKit's document camera, which finds the page edges, crops and
/// straightens each page, and saves the pages as JPEGs for Dart.
public class PolyscanScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
  private var pending: FlutterResult?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "polyscan_scanner", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PolyscanScannerPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(VNDocumentCameraViewController.isSupported)
    case "scan":
      scan(result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func scan(_ result: @escaping FlutterResult) {
    guard VNDocumentCameraViewController.isSupported else {
      result(FlutterError(code: "unavailable", message: "This device has no document camera", details: nil))
      return
    }
    guard pending == nil else {
      result(FlutterError(code: "busy", message: "A scan is already open", details: nil))
      return
    }
    guard let presenter = Self.topViewController() else {
      result(FlutterError(code: "scan_failed", message: "No view controller to present from", details: nil))
      return
    }
    pending = result
    let camera = VNDocumentCameraViewController()
    camera.delegate = self
    presenter.present(camera, animated: true)
  }

  public func documentCameraViewController(
    _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
  ) {
    let pageCount = scan.pageCount
    // Read the images while the scan object is alive, then encode off the main thread.
    let images = (0..<pageCount).map { scan.imageOfPage(at: $0) }
    controller.dismiss(animated: true)
    DispatchQueue.global(qos: .userInitiated).async {
      let outcome = Self.save(images)
      DispatchQueue.main.async { self.finish(outcome) }
    }
  }

  public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
    controller.dismiss(animated: true)
    finish([String]())
  }

  public func documentCameraViewController(
    _ controller: VNDocumentCameraViewController, didFailWithError error: Error
  ) {
    controller.dismiss(animated: true)
    finish(FlutterError(code: "scan_failed", message: error.localizedDescription, details: nil))
  }

  private func finish(_ value: Any) {
    pending?(value)
    pending = nil
  }

  /// Writes each page as a JPEG into the cache folder; returns the paths or a FlutterError.
  static func save(_ images: [UIImage]) -> Any {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("polyscan_scanner", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      let stamp = Int(Date().timeIntervalSince1970 * 1000)
      var paths: [String] = []
      for (i, image) in images.enumerated() {
        guard let data = image.jpegData(compressionQuality: 0.9) else {
          return FlutterError(code: "scan_failed", message: "Could not encode page \(i + 1)", details: nil)
        }
        let url = dir.appendingPathComponent("scan-\(stamp)-\(i + 1).jpg")
        try data.write(to: url, options: .atomic)
        paths.append(url.path)
      }
      return paths
    } catch {
      return FlutterError(code: "scan_failed", message: error.localizedDescription, details: nil)
    }
  }

  static func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow } ?? scenes.first?.windows.first
    var top = window?.rootViewController
    while let presented = top?.presentedViewController { top = presented }
    return top
  }
}
