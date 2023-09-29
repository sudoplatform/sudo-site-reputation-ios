platform :ios, '15.0'

use_frameworks! :linkage => :dynamic # FIXME: :static when bumped to AWS >= 2.17.0
use_modular_headers!
inhibit_all_warnings!

project 'SudoSiteReputation.xcodeproj'

target 'SudoSiteReputation' do
  podspec :name => 'SudoSiteReputation'
  
  target 'SudoSiteReputationTests' do
    use_frameworks!
    podspec :name => 'SudoSiteReputation'
    pod 'MockingbirdFramework', '~> 0.20'
  end
  
  target 'SudoSiteReputationIntegrationTests' do
    podspec :name => 'SudoSiteReputation'
    pod 'SudoProfiles'
    pod 'SudoEntitlements'
    pod 'SudoEntitlementsAdmin'
  end
  
  target 'SudoSiteReputationIntegrationTestHost' do
    podspec :name => 'SudoSiteReputation'
  end
end


# To fix an Xcode 14.3 issue with deployment targets less than 10
post_install do |installer|
    installer.generated_projects.each do |project|
          project.targets.each do |target|
              target.build_configurations.each do |config|
                  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
               end
          end
   end
end
