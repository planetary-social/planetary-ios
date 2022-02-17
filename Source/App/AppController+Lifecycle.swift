//
//  AppController+Lifecycle.swift
//  FBTT
//
//  Created by Christoph on 2/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger

extension AppController {

    func launch() {
        // Stop mission control if it currently started, this way we are sure
        // it is not sending missions while user onboards or logins. start() is called
        // when showing MainViewController
        self.missionControlCenter.stop()
        
        let controller = LaunchViewController()
        self.setRootViewController(controller, animated: false)
        self.syncPushNotificationsSettings()
    }

    func relaunch() {
        Caches.blobs.invalidate()
        self.launch()
    }

    func resume() {
        self.missionControlCenter.resume()
        self.syncPushNotificationsSettings()
    }

    func suspend() {
        self.missionControlCenter.pause()
        Caches.invalidate()
    }

    func exit() {
        self.missionControlCenter.stop()
    }
}

// MARK:- Memory pressure

extension AppController {

    override func didReceiveMemoryWarning() {
        Log.info("AppController.didReceivingMemoryWarning() - invalidating caches")
        Caches.invalidate()
        ssbDisconnectAllPeers()
    }
}
