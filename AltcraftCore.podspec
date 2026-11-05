#
#  AltcraftCore.podspec
#
#  Core module of the Altcraft iOS SDK. Foundation for all other modules.
#

Pod::Spec.new do |s|
  s.name             = 'AltcraftCore'
  s.version          = '0.2.0'
  s.summary          = 'Altcraft Marketing iOS SDK — Core module.'
  s.description      = 'The Core module of the Altcraft Marketing iOS SDK.'
  s.homepage         = 'https://www.altcraft.com'
  s.license          = { :type => 'MIT', :file => 'LICENSE.md' }
  s.author           = { 'Altcraft' => 'support@altcraft.com' }
  s.module_name      = 'AltcraftCore'

  s.ios.deployment_target = '13.0'
  s.swift_version    = '5.0'
  s.source           = { :git => 'https://github.com/altcraft/ios-sdk.git', :tag => s.version.to_s }

  s.source_files     = 'Altcraft/Core/**/*.swift'
  s.exclude_files    = ['**/Package.swift']
  s.pod_target_xcconfig = { 'ENABLE_USER_SCRIPT_SANDBOXING' => 'NO', 'APPLICATION_EXTENSION_API_ONLY' => 'NO' }
  s.resource_bundles = {
    'AltcraftCoreResources' => ['Altcraft/Core/data/db/Core.xcdatamodeld']
  }
end
