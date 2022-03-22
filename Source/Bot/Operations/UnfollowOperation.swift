//
//  UnfollowOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 1/31/21.
//  Copyright © 2021 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import CrashReporting

class UnfollowOperation: AsynchronousOperation {

    var identity: Identity
    private(set) var error: Error?
    
    init(identity: Identity) {
        self.identity = identity
        super.init()
    }
    
    override func main() {
        Log.info("UnfollowOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. UnfollowOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.unfollow(self.identity) { [weak self] (contact, error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.error = error
            Log.info("UnfollowOperation finished.")
            self?.finish()
        }
    }
    
}
