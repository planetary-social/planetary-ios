//
//  AppController+Lifecycle.swift
//  FBTT
//
//  Created by Christoph on 2/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

extension AppController {

    func launch() {
        let controller = LaunchViewController()
        self.setRootViewController(controller, animated: false)
        Timers.pokeTimers.forEach{$0.start()}
        self.syncPushNotificationsSettings()
    }

    func relaunch() {
        //blobs are immutable and we don't delete them, not reason to invalidate their cache.
        //Caches.blobs.invalidate()
        self.launch()
    }

    func resume() {
        Bots.current.resume()
        Timers.pokeTimers.forEach{$0.start()}
        self.syncPushNotificationsSettings()
    }

    func suspend() {
        Bots.current.suspend()
        Timers.pokeTimers.forEach{$0.stop()}
        Caches.invalidate()
    }

    func exit() {
        Bots.current.exit()
    }
}

// MARK:- Memory pressure

extension AppController {

    override func didReceiveMemoryWarning() {
        Log.info("AppController.didReceivingMemoryWarning() - invalidating caches")
        Caches.invalidate()
    }
}
