require 'json'

package = JSON.parse(File.read(File.join(__dir__, '..', 'package.json')))

Pod::Spec.new do |s|
  s.name           = 'ReactNativeDatamatrixScanner'
  s.version        = package['version']
  s.summary        = package['description']
  s.description    = package['description']
  s.license        = package['license']
  s.homepage       = package['homepage'] || 'https://github.com/alprenkrc/react-native-datamatrix-scanner'
  s.author         = package['author']
  s.platforms      = { :ios => '15.0' }
  s.source         = { :git => package['repository'] || '', :tag => s.version.to_s }
  s.static_framework = true

  s.dependency 'ExpoModulesCore'

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'SWIFT_COMPILATION_MODE' => 'wholemodule',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++20',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'USE_HEADERMAP' => 'NO',
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) ZXING_READERS=1 ZXING_EXPERIMENTAL_API=1',
    'HEADER_SEARCH_PATHS' => '"$(PODS_TARGET_SRCROOT)/zxing" "$(PODS_TARGET_SRCROOT)/zxing/datamatrix" "$(PODS_TARGET_SRCROOT)/zxing/aztec" "$(PODS_TARGET_SRCROOT)/zxing/maxicode" "$(PODS_TARGET_SRCROOT)/zxing/oned" "$(PODS_TARGET_SRCROOT)/zxing/pdf417" "$(PODS_TARGET_SRCROOT)/zxing/qrcode" "$(PODS_TARGET_SRCROOT)/zxing/libzint" "$(PODS_TARGET_SRCROOT)/zxing/libzueci"'
  }

  # Exclude libzint stub .h files from headers.
  # These stubs contain only a relative path string (e.g. "../../../zint/backend/eci.h")
  # rather than actual C code. CocoaPods copies them to Pods/Headers/, causing
  # case-insensitive name collision with ZXing's own headers on macOS
  # (libzint/eci.h collides with zxing/ECI.h), producing build errors:
  #   "cannot use dot operator on a type" and "use of undeclared identifier 'ToECI'"
  s.source_files = '**/*.{h,m,mm,swift,cpp,c}'
  s.exclude_files = 'zxing/libzint/**/*'
  s.public_header_files = 'ZXingBridge.h'

  # AVFoundation is a system framework; no extra pod needed.
  s.frameworks = 'AVFoundation'
end
