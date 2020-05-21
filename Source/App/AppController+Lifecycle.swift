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
        Timers.shared.pokeTimers.forEach{$0.start()}
        self.syncPushNotificationsSettings()
    }

    func relaunch() {
        Caches.blobs.invalidate()
        self.launch()
    }

    func resume() {
        self.operationQueue.addOperation(ResumeOperation())
        Timers.shared.pokeTimers.forEach{$0.start()}
        self.syncPushNotificationsSettings()
    }

    func suspend() {
        self.operationQueue.addOperation(SuspendOperation())
        Timers.shared.pokeTimers.forEach{$0.stop()}
        Caches.invalidate()
    }

    func exit() {
        self.operationQueue.addOperation(ExitOperation())
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
