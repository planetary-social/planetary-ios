//
//  RedeemInviteOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class RedeemInviteOperation: AsynchronousOperation {

    var token: String
    private(set) var error: Error?
    
    init(token: String) {
        self.token = token
        super.init()
    }
    
    override func main() {
        Log.info("RedeemInviteOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. RedeemInviteOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Log.debug("Redeeming invite \(token)...")
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.inviteRedeem(queue: queue, token: self.token) { [weak self] (error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            self?.error = error
            Log.info("RedeemInviteOperation finished.")
            self?.finish()
        }
    }
    
}
