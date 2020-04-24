//
//  AppDelegate.swift
//  FBTT
//
//  Created by Christoph on 12/14/18.
//  Copyright © 2018 Verse Communications Inc. All rights reserved.
//

import UIKit

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
        
        Log.configure()
        CrashReporting.shared.configure()
        
        // reset configurations if user enabled switch in settings
        self.resetIfNeeded()

        // next
        // repairs are tracked so analytics must be configured first
        Analytics.configure()
        self.repair20200116()

        // then
        Support.shared.configure()
        self.configureAppearance()
        self.configureBackground()
        self.configureNotifications()
        AppController.shared.launch()

        CrashReporting.shared.record("Launch")
        Analytics.trackAppLaunch()
        
        // done
        return true
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        CrashReporting.shared.record("App will enter foreground")
        AppController.shared.resume()
        Analytics.trackAppForeground()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        CrashReporting.shared.record("App will terminate")
        AppController.shared.exit()
        Analytics.trackAppExit()
    }
}
