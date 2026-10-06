Pod::Spec.new do |s|
  s.name             = 'polyscan_ocr'
  s.version          = '0.1.0'
  s.summary          = 'On-device Tesseract OCR for Polyscan.'
  s.description      = 'Runs Tesseract 5 (LSTM) on device with language models loaded from any folder.'
  s.homepage         = 'https://github.com/pickixo/polyscan'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Pickixo' => 'monjurhye@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'polyscan_ocr/Sources/polyscan_ocr/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'

  # Built by ios/scripts/build_tesseract.sh; not checked in.
  s.vendored_frameworks = 'polyscan_ocr/TesseractC.xcframework'
  s.libraries = 'c++'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'polyscan_ocr_privacy' => ['polyscan_ocr/Sources/polyscan_ocr/PrivacyInfo.xcprivacy']}
end
