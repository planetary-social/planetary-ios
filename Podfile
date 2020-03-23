# Uncomment the next line to define a global platform for your project
platform :ios, '12.1'
use_frameworks!

# ignore all warnings from all pods
inhibit_all_warnings!

target 'Planetary' do
    pod 'ImageSlideshow', '1.8.3'
    pod 'KeychainSwift', '15.0.0'
    pod 'Mixpanel', '3.5.1'
    pod 'PhoneNumberKit', '2.6.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'SwiftyMarkdown', '0.6.0'
    pod 'SVProgressHUD', '2.2.5'
    pod 'ZendeskSDK', '3.0.3'
    pod 'CocoaLumberjack/Swift', '3.6.1'
    pod 'Bugsnag', '5.23.0'
end

target 'APITests' do
    pod 'KeychainSwift', '15.0.0'
    pod 'PhoneNumberKit', '2.6.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'SwiftyMarkdown', '0.6.0'
end

target 'UnitTests' do
    pod 'KeychainSwift', '15.0.0'
    pod 'Multipart', '0.1.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'SwiftyMarkdown', '0.6.0'
end

target 'UITests' do
end

post_install do | installer |

    # copy Acknowledgements into Settings bundle
    require 'fileutils'
    FileUtils.cp_r('Pods/Target Support Files/Pods-Planetary/Pods-Planetary-acknowledgements.plist', 'Resources/Settings.bundle/Acknowledgements.plist', :remove_destination => true)

    # force pods project to Build Libraries for Distribution build setting
    # this is required for Swift 5.1 module compatibility
    installer.pods_project.targets.each do |target|
      target.build_configurations.each do |config|
          config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      end
    end

    # force pods project to only include dSYM with debug builds
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['DEBUG_INFORMATION_FORMAT'] = 'dwarf'
            config.build_settings['ENABLE_BITCODE'] = 'NO'
        end
    end
end
