platform :ios, '15.0'

use_frameworks! :linkage => :dynamic # FIXME: :static when bumped to AWS >= 2.17.0
use_modular_headers!
inhibit_all_warnings!

target 'SudoSiteReputation'
target 'SudoSiteReputationTests'
target 'SudoSiteReputationIntegrationTests'

podspec :name => 'SudoSiteReputation'

# HACK: Remove when bumped to AWSAppSync >= 3.1.9
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      if config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] == '8.0'
        config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '9.0'
      end
    end
  end
end
