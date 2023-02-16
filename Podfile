platform :ios, '15.0'

use_frameworks! :linkage => :dynamic # FIXME: :static when bumped to AWS >= 2.17.0
use_modular_headers!
inhibit_all_warnings!

target 'SudoSiteReputation'
target 'SudoSiteReputationTests' do
  use_frameworks!
  pod 'MockingbirdFramework', '~> 0.20'
end
target 'SudoSiteReputationIntegrationTests'

podspec :name => 'SudoSiteReputation'
