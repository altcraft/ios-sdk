#
#  AltcraftPush.podspec
#
#  Push module of the Altcraft iOS SDK. Depends transitively on AltcraftCore.
#

Pod::Spec.new do |s|
  s.name             = 'AltcraftPush'
  s.version          = '0.2.0'
  s.summary          = 'Altcraft Marketing iOS SDK — Push module.'
  s.description      = 'The Push module of the Altcraft Marketing iOS SDK.'
  s.homepage         = 'https://www.altcraft.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Altcraft' => 'support@altcraft.com' }
  s.module_name      = 'AltcraftPush'

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.source           = { :git => 'https://github.com/altcraft/ios-sdk.git', :tag => s.version.to_s }

  s.source_files     = 'Altcraft/Push/**/*.swift'
  s.exclude_files    = ['**/Package.swift']
  s.pod_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO', 'APPLICATION_EXTENSION_API_ONLY' => 'NO' }
  s.resource_bundles = {
    'AltcraftPushResources' => [
      'Altcraft/Push/data/db/Push.xcdatamodeld',
      'Altcraft/Push/PrivacyInfo.xcprivacy'
    ]
  }

  s.dependency 'AltcraftCore', '~> 0.2.0'
end
