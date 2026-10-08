Pod::Spec.new do |s|
  s.name             = 'polyscan_scanner'
  s.version          = '0.1.0'
  s.summary          = 'Document scanner for Polyscan.'
  s.description      = 'Shows VisionKit's document camera and returns the cropped pages as JPEG files.'
  s.homepage         = 'https://github.com/monjurhye/polyscan'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Pickixo' => 'monjurhye@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'polyscan_scanner/Sources/polyscan_scanner/**/*.swift'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks = 'VisionKit'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
  s.resource_bundles = {'polyscan_scanner_privacy' => ['polyscan_scanner/Sources/polyscan_scanner/PrivacyInfo.xcprivacy']}
end
