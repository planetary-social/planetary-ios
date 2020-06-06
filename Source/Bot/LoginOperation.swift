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
    private(set) var success: Bool = false
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
        
        // Unwrapping this values is safe because canLaunch() verify them
        let identity = configuration.identity!
        let network = configuration.network!
        let hmacKey = configuration.hmacKey
        let secret = configuration.secret!
        
        if let loggedInIdentity = Bots.current.identity, loggedInIdentity == identity {
            self.success = true
            self.finish()
        } else {
            Bots.current.login(network: network, hmacKey: hmacKey, secret: secret) { [weak self] (error) in
                if let strongSelf = self, !strongSelf.isCancelled {
                    self?.success = ((error as? BotError) == .alreadyLoggedIn) || error == nil
                    self?.error = error
                }
                self?.finish()
            }
        }
     }
    
}
