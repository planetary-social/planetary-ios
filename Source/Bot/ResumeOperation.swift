//
//  ResumeOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 5/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class ResumeOperation: AsynchronousOperation {

    private(set) var error: Error?
    
    override func main() {
        Log.info("ResumeOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. ResumeOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Bots.current.resume()
        
        Log.info("ResumeOperation finished.")
    }
    
}
