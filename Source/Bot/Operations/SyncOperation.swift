//
//  SyncOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Analytics
import CrashReporting

/// Tries to connect to the given peers to gossip with them. Don't use this SyncOperation directly, use
/// SendMissionOperation instead.
class SyncOperation: AsynchronousOperation {
    
    /// List of available rooms to establish connection. All will be connected to.
    var rooms: [MultiserverAddress]
    
    /// List of available peers to establish connection. Only a subset will be actually be connected to.
    var pubs: [MultiserverAddress]
    
    /// If true, only will sync to one peer with no retries
    var notificationsOnly = false
    
    private(set) var error: Error?
    
    init(rooms: [MultiserverAddress], pubs: [MultiserverAddress]) {
        self.rooms = rooms
        self.pubs = pubs
        super.init()
    }
     
    override func main() {
        Log.info("SyncOperation (notificationsOnly=\(notificationsOnly)) started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. SyncOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.sync(queue: dispatchQueue, peers: pubs) { [weak self] (error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.info("Dialing rooms")
            self?.rooms.forEach {
                Bots.current.connect(to: $0)
            }
            if let strongSelf = self, !strongSelf.isCancelled {
                self?.error = error
            }
            Log.info("SyncOperation finished.")
            self?.finish()
        }
    }
}
