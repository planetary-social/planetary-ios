//
//  LoginOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class LoginOperation: AsynchronousOperation {
    
    var configuration: AppConfiguration
    private(set) var success = false
    private(set) var error: Error?
    
    init(configuration: AppConfiguration) {
        self.configuration = configuration
        super.init()
    }
     
    override func main() {
        guard configuration.canLaunch else {
            self.finish()
            return
        }
        
        let identity = configuration.identity
        
        if let loggedInIdentity = Bots.current.identity, loggedInIdentity == identity {
            self.success = true
            self.finish()
        } else {
            Task {
                do {
                    try await Bots.current.login(config: configuration, fromOnboarding: false)
                    self.success = true
                } catch {
                    if error as? BotError == .alreadyLoggedIn {
                        self.success = true
                    } else {
                        self.success = false
                        self.error = error
                    }
                }
                self.finish()
            }
        }
    }
}
