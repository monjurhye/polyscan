import Flutter
import TesseractC
import UIKit
import Vision

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
      let config = EngineConfig(
        imagePath: imagePath, tessdataDir: tessdataDir, languages: languages,
        pageSegMode: args["pageSegMode"] as? Int ?? 3,
        variables: args["variables"] as? [String: String] ?? [:])
      queue.async {
        let outcome = Self.recognize(config)
        DispatchQueue.main.async {
          switch outcome {
          case .success(let map): result(map)
          case .failure(let error): result(FlutterError(code: error.code, message: error.message, details: nil))
          }
        }
      }
    case "recognizeSystem":
      guard let args = call.arguments as? [String: Any],
            let imagePath = args["imagePath"] as? String,
            let languages = args["languages"] as? [String]
      else {
        result(FlutterError(code: "bad_args", message: "imagePath and languages are required", details: nil))
        return
      }
      queue.async {
        let outcome = Self.recognizeWithVision(imagePath: imagePath, languages: languages)
        DispatchQueue.main.async {
          switch outcome {
          case .success(let map): result(map)
          case .failure(let error): result(FlutterError(code: error.code, message: error.message, details: nil))
          }
        }
      }
    case "systemLanguages":
      result((try? VNRecognizeTextRequest().supportedRecognitionLanguages()) ?? [])
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Tesseract codes and the Apple Vision languages that read the same text.
  static let visionLanguages: [String: String] = [
    "eng": "en-US", "spa": "es-ES", "fra": "fr-FR", "deu": "de-DE", "por": "pt-BR", "ita": "it-IT",
    "nld": "nl-NL", "pol": "pl-PL", "ces": "cs-CZ", "dan": "da-DK", "nor": "nb-NO", "swe": "sv-SE",
    "ron": "ro-RO", "tur": "tr-TR", "ind": "id-ID", "msa": "ms-MY", "vie": "vi-VT", "rus": "ru-RU",
    "ukr": "uk-UA", "tha": "th-TH", "ara": "ar-SA", "chi_sim": "zh-Hans", "chi_tra": "zh-Hant",
    "jpn": "ja-JP", "kor": "ko-KR",
  ]

  /// Reads [imagePath] with Apple Vision when this iOS version supports every language
  /// asked for. Returns nil (not an error) when it doesn't, so the caller uses Tesseract.
  static func recognizeWithVision(imagePath: String, languages: [String]) -> Result<[String: Any]?, OcrError> {
    guard let image = UIImage(contentsOfFile: imagePath), let cgImage = image.cgImage else {
      return .failure(OcrError(code: "bad_image", message: "Cannot read image at \(imagePath)"))
    }

    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true

    // Which languages this device's Vision reads differs by iOS version, so ask it.
    guard let supported = try? request.supportedRecognitionLanguages() else { return .success(nil) }
    var codes: [String] = []
    for language in languages {
      guard let wanted = visionLanguages[language] else { return .success(nil) }
      let base = wanted.split(separator: "-").first.map(String.init) ?? wanted
      guard let match = supported.first(where: { $0 == wanted }) ?? supported.first(where: { $0.hasPrefix(base) })
      else { return .success(nil) }
      codes.append(match)
    }
    request.recognitionLanguages = codes

    let width = cgImage.width, height = cgImage.height
    do {
      try VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:]).perform([request])
    } catch {
      // Some simulators and older devices can't run Vision's text model; Tesseract still can.
      NSLog("polyscan_ocr: Vision failed (\(error)); falling back to Tesseract")
      return .success(nil)
    }

    var lines: [String] = []
    var words: [[String: Any]] = []
    var confidenceSum: Float = 0
    for observation in request.results ?? [] {
      guard let candidate = observation.topCandidates(1).first else { continue }
      let line = candidate.string
      lines.append(line)
      confidenceSum += candidate.confidence
      line.enumerateSubstrings(in: line.startIndex..<line.endIndex, options: .byWords) { word, range, _, _ in
        guard let word = word, let box = try? candidate.boundingBox(for: range)?.boundingBox else { return }
        // Vision boxes are normalized with the origin at the bottom left.
        words.append([
          "text": word,
          "left": Int(box.minX * CGFloat(width)), "top": Int((1 - box.maxY) * CGFloat(height)),
          "right": Int(box.maxX * CGFloat(width)), "bottom": Int((1 - box.minY) * CGFloat(height)),
          "confidence": Double(candidate.confidence * 100),
        ])
      }
    }
    let mean = lines.isEmpty ? 0 : Int(confidenceSum / Float(lines.count) * 100)
    return .success([
      "text": lines.joined(separator: "\n") + (lines.isEmpty ? "" : "\n"),
      "meanConfidence": mean,
      "words": words,
      "imageWidth": width,
      "imageHeight": height,
      "engine": "vision",
    ])
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
        "engine": "tesseract",
      ])
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
