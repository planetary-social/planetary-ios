//
//  FollowOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/13/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

class FollowOperation: AsynchronousOperation {

    var identity: Identity
    private(set) var error: Error?
    
    init(identity: Identity) {
        self.identity = identity
        super.init()
    }
    
    override func main() {
        Log.info("FollowOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. FollowOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.follow(self.identity) { [weak self] (contact, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.error = error
            Log.info("FollowOperation finished.")
            self?.finish()
        }
    }
    
}
