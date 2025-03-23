#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint aio_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'aio_scanner'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for scanning documents using VisionKit for iOS and ML Kit for Android.'
  s.description      = <<-DESC
A Flutter plugin for scanning documents and barcodes using VisionKit for iOS and ML Kit for Android.
                       DESC
  s.homepage         = 'https://github.com/troyvnit/aio_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Troy Lee' => 'troyvnit@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '16.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end 