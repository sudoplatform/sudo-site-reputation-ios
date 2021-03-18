Pod::Spec.new do |spec|
  spec.name                  = 'SudoSiteReputation'
  spec.version               = ENV['PUBLISHER_PODSPEC_VERSION'] || '0.0.1'
  spec.author                = { 'Sudo Platform Engineering' => 'sudoplatform-engineering@anonyome.com' }
  spec.homepage              = 'https://sudoplatform.com'
  spec.summary               = 'Site Reputation SDK for the Sudo Platform by Anonyome Labs.'
  spec.license               = { :type => 'Apache License, Version 2.0', :file => 'LICENSE' }
  spec.source                = { :git => 'https://github.com/sudoplatform/sudo-site-reputation-ios.git', :tag => "#{spec.version}" }
  spec.source_files          = "SudoSiteReputation/**/*.swift"
  spec.ios.deployment_target = '13.0'
  spec.requires_arc          = true
  spec.swift_version         = '5.0'

  spec.dependency 'SudoLogging', '~> 0.3'
  spec.dependency 'SudoUser', '>= 10.0', '< 12.0'
end
