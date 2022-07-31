//
//  RefreshOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Analytics
import CrashReporting

class RefreshOperation: AsynchronousOperation {

    private var refreshLoad: RefreshLoad = .medium
    private(set) var error: Error?
    
    init(refreshLoad: RefreshLoad) {
        self.refreshLoad = refreshLoad
    }
    
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
        
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.refresh(load: refreshLoad, queue: queue) { [weak self, refreshLoad] (refreshResult, timeElapsed) in
            var error: Error?
            if case .failure(let actualError) = refreshResult {
                error = actualError
            }
            Analytics.shared.trackBotDidRefresh(load: refreshLoad.rawValue, duration: timeElapsed, error: error)
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            
            Log.info("RefreshOperation finished. Took \(timeElapsed) seconds to refresh.")
            if let strongSelf = self, !strongSelf.isCancelled {
                self?.error = error
            }
            self?.finish()
        }
    }
}
