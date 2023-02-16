//
//  RefreshOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
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
        
        Bots.current.refresh(
            load: refreshLoad,
            queue: dispatchQueue
        ) { [weak self] (refreshResult, timeElapsed) in
            var error: Error?
            if case .failure(let actualError) = refreshResult {
                error = actualError
            }
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
