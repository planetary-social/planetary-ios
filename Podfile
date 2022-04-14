# Uncomment the next line to define a global platform for your project
platform :ios, '12.1'
use_frameworks!
project 'Planetary', 'Test' => :debug

# ignore all warnings from all pods
inhibit_all_warnings!

target 'Planetary' do
    pod 'ImageSlideshow', '1.8.3'
    pod 'KeychainSwift', '19.0.0'
    pod 'PhoneNumberKit', '3.2.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'SVProgressHUD', '2.2.5'
    pod 'Down', '0.9.2'
    pod 'SkeletonView', '1.8.7'
end

target 'APITests' do
    pod 'KeychainSwift', '19.0.0'
    pod 'PhoneNumberKit', '3.2.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'Down', '0.9.2'
end

target 'UnitTests' do
    pod 'KeychainSwift', '19.0.0'
    pod 'Multipart', '0.1.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'Down', '0.9.2'
end

target 'UITests' do
    pod 'KeychainSwift', '19.0.0'
    pod 'PhoneNumberKit', '3.2.0'
    pod 'SQLite.swift', '0.12.2'
    pod 'Down', '0.9.2'
end

post_install do | installer |

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

    # Silence deployment target warnings.
    installer.pods_project.targets.each do |target|
        target.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
        end
    end
end
