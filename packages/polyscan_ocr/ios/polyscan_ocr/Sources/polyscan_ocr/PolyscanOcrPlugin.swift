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
    case "recognize":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String,
            let tessdataDir = args["tessdataDir"] as? String,
            let languages = args["languages"] as? String
      else {
        result(FlutterError(code: "bad_args", message: "imagePath, tessdataDir and languages are required", details: nil))
        return
      }
      let pageSegMode = args["pageSegMode"] as? Int ?? 3
      let variables = args["variables"] as? [String: String] ?? [:]
      queue.async {
        let outcome = Self.recognize(
          imagePath: imagePath, tessdataDir: tessdataDir, languages: languages,
          pageSegMode: pageSegMode, variables: variables)
        DispatchQueue.main.async {
          switch outcome {
          case .success(let map): result(map)
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

  static func recognize(
    imagePath: String, tessdataDir: String, languages: String,
    pageSegMode: Int, variables: [String: String]
  ) -> Result<[String: Any], OcrError> {
    guard let image = UIImage(contentsOfFile: imagePath) else {
      return .failure(OcrError(code: "bad_image", message: "Cannot read image at \(imagePath)"))
    }
    guard let gray = grayscalePixels(image) else {
      return .failure(OcrError(code: "bad_image", message: "Cannot decode image at \(imagePath)"))
    }

    guard let api = TessBaseAPICreate() else {
      return .failure(OcrError(code: "init_failed", message: "TessBaseAPICreate failed"))
    }
    defer {
      TessBaseAPIEnd(api)
      TessBaseAPIDelete(api)
    }

    if TessBaseAPIInit2(api, tessdataDir, languages, OEM_LSTM_ONLY) != 0 {
      return .failure(OcrError(
        code: "init_failed",
        message: "Could not load '\(languages)' from \(tessdataDir)"))
    }
    for (name, value) in variables {
      TessBaseAPISetVariable(api, name, value)
    }
    TessBaseAPISetPageSegMode(api, TessPageSegMode(rawValue: UInt32(pageSegMode)))

    gray.pixels.withUnsafeBufferPointer { buffer in
      TessBaseAPISetImage(api, buffer.baseAddress, Int32(gray.width), Int32(gray.height), 1, Int32(gray.width))
    }
    TessBaseAPISetSourceResolution(api, 300)

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
      "imageWidth": gray.width,
      "imageHeight": gray.height,
    ])
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
