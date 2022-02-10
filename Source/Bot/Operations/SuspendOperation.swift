//
//  SuspendOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 5/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

class SuspendOperation: AsynchronousOperation {

    private(set) var error: Error?
    
    override func main() {
        Log.info("SuspendOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. SuspendOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.suspend()
        
        Log.info("SuspendOperation finished.")
        self.finish()
    }
    
}
