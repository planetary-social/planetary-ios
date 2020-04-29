//
//  RefreshOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class RefreshOperation: AsynchronousOperation {

    var refreshLoad: RefreshLoad = .short
    private(set) var error: Error?
    
    override func main() {
        Log.info("RefreshOperation started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. RefreshOperation finished.")
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        Analytics.trackBotRefresh()
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.refresh(load: refreshLoad, queue: queue) { [weak self, refreshLoad] (error, timeInterval) in
            Analytics.trackBotDidRefresh(load: refreshLoad, duration: timeInterval, error: error)
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            Log.info("RefreshOperation finished. Took \(timeInterval) seconds to refresh.")
            if let strongSelf = self, !strongSelf.isCancelled {
                self?.error = error
            }
            self?.finish()
        }
    }
    
}
