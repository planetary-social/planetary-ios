//
//  AppDelegate.swift
//  FBTT
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger
import Analytics
import CrashReporting

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // first
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = AppController.shared
        window.makeKeyAndVisible()
        self.window = window

        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "missing"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "missing"
        Log.info("Launching version: \(appVersion) (\(appBuild))")
        CrashReporting.shared.record("Launch")

        registerDefaultsFromSettingsBundle()
        
        // reset configurations if user enabled switch in settings
        self.resetIfNeeded()
        
        if CommandLine.arguments.contains("use-ci-network") {
            AppConfiguration.current?.unapply()
        }

        // next
        self.repair20200116()

        // then
        self.configureAppearance()
        self.configureBackgroundAppRefresh()
        self.configureNotifications()
        AppController.shared.launch()

        Analytics.shared.trackAppLaunch()
        
        // Ignore SIGPIPE signals
        // Check https://apple.co/2ZXayG9 for more info.
        Darwin.signal(SIGPIPE, SIG_IGN)
        
        // done
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        CrashReporting.shared.record("App will enter foreground")
        AppController.shared.resume()
        Analytics.shared.trackAppForeground()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CrashReporting.shared.record("App will terminate")
        AppController.shared.exit()
        Analytics.shared.trackAppExit()
    }
    
    /// Loads the default values for the Planetary settings in Settings.app into UserDefaults. Idempotent.
    /// From https://stackoverflow.com/a/61409298/982195
    func registerDefaultsFromSettingsBundle() {
        let settingsName                    = "Settings"
        let settingsExtension               = "bundle"
        let settingsRootPlist               = "Root.plist"
        let settingsPreferencesItems        = "PreferenceSpecifiers"
        let settingsPreferenceKey           = "Key"
        let settingsPreferenceDefaultValue  = "DefaultValue"

        guard let settingsBundleURL = Bundle.main.url(forResource: settingsName, withExtension: settingsExtension),
            let settingsData = try? Data(contentsOf: settingsBundleURL.appendingPathComponent(settingsRootPlist)),
            let settingsPlist = try? PropertyListSerialization.propertyList(
                from: settingsData,
                options: [],
                format: nil
            ) as? [String: Any],
            let settingsPreferences = settingsPlist[settingsPreferencesItems] as? [[String: Any]] else {
                return
        }

        var defaultsToRegister = [String: Any]()

        settingsPreferences.forEach { preference in
            if let key = preference[settingsPreferenceKey] as? String {
                defaultsToRegister[key] = preference[settingsPreferenceDefaultValue]
            }
        }

        UserDefaults.standard.register(defaults: defaultsToRegister)
    }
}
