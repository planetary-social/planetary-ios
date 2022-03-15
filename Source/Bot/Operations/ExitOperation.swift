//
//  ExitOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 5/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

class ExitOperation: AsynchronousOperation {

    private(set) var error: Error?
    
    override func main() {
        Log.info("ExitOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. ExitOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.exit()
        
        Log.info("ExitOperation finished.")
        self.finish()
    }
    
}
