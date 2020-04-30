//
//  AppController+Lifecycle.swift
//  FBTT
//
//  Created by Christoph on 2/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AppController {

    func launch() {
        let controller = LaunchViewController()
        self.setRootViewController(controller, animated: false)
        Timers.pokeTimer.start()
        self.syncPushNotificationsSettings()
    }

    func relaunch() {
        //blobs are immutable and we don't delete them, not reason to invalidate their cache.
        //Caches.blobs.invalidate()
        self.launch()
    }

    func resume() {
        Bots.current.resume()
        Timers.pokeTimer.start(fireImmediately: true)
        self.syncPushNotificationsSettings()
    }

    /// Pokes the bot into doing a sync, but only if logged in, and only if
    /// not during an onboarding process.
    func poke() {
        guard let identity = Bots.current.identity else { return }
        guard Onboarding.status(for: identity) == .completed else { return }
        Log.info("Poking the bot into doing a sync")
        self.loginAndSync()
    }

    func suspend() {
        Bots.current.suspend()
        Timers.pokeTimer.stop()
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
