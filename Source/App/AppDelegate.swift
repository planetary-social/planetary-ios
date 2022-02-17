//
//  AppDelegate.swift
//  FBTT
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import UIKit
import Logger

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    {
        // first
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = AppController.shared
        window.makeKeyAndVisible()
        self.window = window
        
        CrashReporting.shared.record("Launch")
        
        // reset configurations if user enabled switch in settings
        self.resetIfNeeded()
        
        if CommandLine.arguments.contains("use-ci-network") {
            AppConfiguration.current?.unapply()
        }

        // next
        self.repair20200116()

        // then
        self.configureAppearance()
        self.configureBackground()
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
}
