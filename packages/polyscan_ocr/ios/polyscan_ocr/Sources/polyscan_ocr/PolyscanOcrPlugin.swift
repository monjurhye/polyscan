import Flutter
import TesseractC
import UIKit

public class PolyscanOcrPlugin: NSObject, FlutterPlugin {
  private let queue = DispatchQueue(label: "com.pickixo.polyscan_ocr", qos: .userInitiated)

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "polyscan_ocr", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(PolyscanOcrPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "tesseractVersion":
      result(String(cString: TessVersion()))
    case "recognize", "recognizeRegions":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String,
            let tessdataDir = args["tessdataDir"] as? String,
            let languages = args["languages"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "imagePath, tessdataDir and languages are required", details: nil))
        return
      }
      let config = EngineConfig(
        imagePath: imagePath, tessdataDir: tessdataDir, languages: languages,
        pageSegMode: args["pageSegMode"] as? Int ?? 3,
        variables: args["variables"] as? [String: String] ?? [:])
      let regions = (args["regions"] as? [[Int]]) ?? []
      let method = call.method
      queue.async {
        let outcome: Result<Any, OcrError>
        if method == "recognize" {
          outcome = Self.recognize(config).map { $0 as Any }
        } else {
          outcome = Self.recognizeRegions(config, regions: regions).map { $0 as Any }
        }
        DispatchQueue.main.async {
          switch outcome {
          case .success(let value): result(value)
          case .failure(let error): result(FlutterError(code: error.code, message: error.message, details: nil))
          }
        }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  struct OcrError: Error {
    let code: String
    let message: String
  }

  struct EngineConfig {
    let imagePath: String
    let tessdataDir: String
    let languages: String
    let pageSegMode: Int
    let variables: [String: String]
  }

  /// Loads the image and an initialised Tesseract engine, runs [body], then frees the engine.
  static func withEngine<T>(
    _ config: EngineConfig,
    _ body: (OpaquePointer, Int, Int) -> Result<T, OcrError>
  ) -> Result<T, OcrError> {
    guard let image = UIImage(contentsOfFile: config.imagePath) else {
      return .failure(OcrError(code: "bad_image", message: "Cannot read image at \(config.imagePath)"))
    }
    guard let gray = grayscalePixels(image) else {
      return .failure(OcrError(code: "bad_image", message: "Cannot decode image at \(config.imagePath)"))
    }

    guard let api = TessBaseAPICreate() else {
      return .failure(OcrError(code: "init_failed", message: "TessBaseAPICreate failed"))
    }
    defer {
      TessBaseAPIEnd(api)
      TessBaseAPIDelete(api)
    }

    if TessBaseAPIInit2(api, config.tessdataDir, config.languages, OEM_LSTM_ONLY) != 0 {
      return .failure(OcrError(
        code: "init_failed",
        message: "Could not load '\(config.languages)' from \(config.tessdataDir)"))
    }
    for (name, value) in config.variables {
      TessBaseAPISetVariable(api, name, value)
    }
    TessBaseAPISetPageSegMode(api, TessPageSegMode(rawValue: UInt32(config.pageSegMode)))

    gray.pixels.withUnsafeBufferPointer { buffer in
      TessBaseAPISetImage(api, buffer.baseAddress, Int32(gray.width), Int32(gray.height), 1, Int32(gray.width))
    }
    TessBaseAPISetSourceResolution(api, 300)
    return body(api, gray.width, gray.height)
  }

  static func recognize(_ config: EngineConfig) -> Result<[String: Any], OcrError> {
    withEngine(config) { api, width, height in
      if TessBaseAPIRecognize(api, nil) != 0 {
        return .failure(OcrError(code: "recognize_failed", message: "Tesseract could not read the image"))
      }

      var text = ""
      if let cText = TessBaseAPIGetUTF8Text(api) {
        text = String(cString: cText)
        TessDeleteText(cText)
      }

      var words: [[String: Any]] = []
      if let iterator = TessBaseAPIGetIterator(api) {
        defer { TessResultIteratorDelete(iterator) }
        let page = TessResultIteratorGetPageIteratorConst(iterator)
        repeat {
          guard let cWord = TessResultIteratorGetUTF8Text(iterator, RIL_WORD) else { continue }
          let word = String(cString: cWord)
          TessDeleteText(cWord)
          var left: Int32 = 0, top: Int32 = 0, right: Int32 = 0, bottom: Int32 = 0
          TessPageIteratorBoundingBox(page, RIL_WORD, &left, &top, &right, &bottom)
          words.append([
            "text": word,
            "left": Int(left), "top": Int(top), "right": Int(right), "bottom": Int(bottom),
            "confidence": Double(TessResultIteratorConfidence(iterator, RIL_WORD)),
          ])
        } while TessResultIteratorNext(iterator, RIL_WORD) != 0
      }

      return .success([
        "text": text,
        "meanConfidence": Int(TessBaseAPIMeanTextConf(api)),
        "words": words,
        "imageWidth": width,
        "imageHeight": height,
      ])
    }
  }

  /// Reads each [left, top, right, bottom] region on its own. Used to re-read numbers.
  static func recognizeRegions(_ config: EngineConfig, regions: [[Int]]) -> Result<[[String: Any]], OcrError> {
    withEngine(config) { api, width, height in
      var results: [[String: Any]] = []
      for region in regions where region.count == 4 {
        let left = max(0, region[0]), top = max(0, region[1])
        let right = min(width, region[2]), bottom = min(height, region[3])
        guard right > left, bottom > top else {
          results.append(["text": "", "confidence": 0.0])
          continue
        }
        TessBaseAPISetRectangle(api, Int32(left), Int32(top), Int32(right - left), Int32(bottom - top))
        var text = ""
        if let cText = TessBaseAPIGetUTF8Text(api) {
          text = String(cString: cText)
          TessDeleteText(cText)
        }
        results.append([
          "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
          "confidence": Double(TessBaseAPIMeanTextConf(api)),
        ])
      }
      return .success(results)
    }
  }

  /// Redraws the image upright (honouring EXIF orientation) into an 8-bit grayscale buffer.
  static func grayscalePixels(_ image: UIImage) -> (pixels: [UInt8], width: Int, height: Int)? {
    let width = Int(image.size.width * image.scale)
    let height = Int(image.size.height * image.scale)
    guard width > 0, height > 0 else { return nil }

    var pixels = [UInt8](repeating: 255, count: width * height)
    let drawn: Bool = pixels.withUnsafeMutableBytes { raw in
      guard let context = CGContext(
        data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
        bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
        bitmapInfo: CGImageAlphaInfo.none.rawValue)
      else { return false }
      // UIKit draws top-down; flip the CG context so the buffer is not upside down.
      context.translateBy(x: 0, y: CGFloat(height))
      context.scaleBy(x: 1, y: -1)
      UIGraphicsPushContext(context)
      image.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
      UIGraphicsPopContext()
      return true
    }
    return drawn ? (pixels, width, height) : nil
  }
}
