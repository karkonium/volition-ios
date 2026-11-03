Pod::Spec.new do |s|
  s.name = 'VolitionScreenTime'
  s.version = '1.0.0'
  s.summary = 'Volition coordinated Screen Time enforcement'
  s.description = s.summary
  s.license = { :type => 'MIT' }
  s.author = 'Volition'
  s.homepage = 'https://github.com/itsRares/volition-ios'
  s.platforms = { :ios => '18.0' }
  s.source = { :path => '.' }
  s.static_framework = true
  s.dependency 'ExpoModulesCore'
  s.source_files = '**/*.swift'
  s.resources = 'Shared/Copy.xcstrings'
  s.frameworks = 'FamilyControls', 'ManagedSettings', 'ManagedSettingsUI', 'DeviceActivity', 'ActivityKit', 'SwiftUI', 'UserNotifications'
  s.swift_version = '5.0'
  s.pod_target_xcconfig = { 'SWIFT_STRICT_CONCURRENCY' => 'complete', 'SWIFT_TREAT_WARNINGS_AS_ERRORS' => 'YES', 'SWIFT_UPCOMING_FEATURE_INFER_SENDABLE_FROM_CAPTURES' => 'YES' }
end
