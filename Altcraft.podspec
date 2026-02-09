Pod::Spec.new do |s|
  s.name             = 'Altcraft'
  s.version          = '1.0.2'
  s.summary          = 'Altcraft iOS SDK.'
  s.description      = <<-DESC
Altcraft iOS SDK is a library that provides seamless integration with the Altcraft API, enabling iOS applications to interact with the Altcraft marketing platform efficiently.
  DESC
  s.license          = { :type => 'EULA', :file => 'LICENSE.md' }
  s.homepage         = 'https://github.com/altcraft/ios-sdk'
  s.source           = { :git => 'https://github.com/altcraft/ios-sdk.git', :tag => s.version.to_s }
  s.authors          = { 'Altcraft' => 'contact@altcraft.com' }

  s.platform         = :ios, '13.0'
  s.swift_versions   = ['5.10']

  s.static_framework = true

  s.source_files     = 'Altcraft/**/*.{swift}'
  s.exclude_files    = 'AltcraftTests/**'

  s.resource_bundles = {
    'AltcraftResources' => [
      'Altcraft/DataBase/**/*.{xcdatamodeld,xcdatamodel,momd,mom}'
    ]
  }

  s.frameworks       = [
    'UIKit',
    'Foundation',
    'CoreData',
    'CryptoKit',
    'BackgroundTasks',
    'Network',
    'UserNotifications',
    'MobileCoreServices'
  ]

  s.weak_frameworks  = ['AdSupport']
  s.requires_arc     = true

  s.user_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO' }
  s.pod_target_xcconfig  = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO' }
end
