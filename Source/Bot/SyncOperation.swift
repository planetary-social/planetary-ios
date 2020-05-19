//
//  SyncOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class SyncOperation: AsynchronousOperation {
    
    var notificationsOnly: Bool = false
    private(set) var newMessages: Int = 0
    private(set) var error: Error?
     
    override func main() {
        Log.info("SyncOperation (notificationsOnly=\(notificationsOnly)) started.")
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. SyncOperation finished.")
            self.newMessages = -1
            self.error = BotError.notLoggedIn
            self.finish()
            return
        }
        
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        if notificationsOnly {
            Analytics.trackBotSync()
            Bots.current.syncNotifications(queue: queue) { [weak self] (error, timeInterval, newMessages) in
                Analytics.trackBotDidSync(duration: timeInterval,
                                          numberOfMessages: newMessages,
                                          error: error)
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.info("SyncOperation finished with \(newMessages) new messages. Took \(timeInterval) seconds to sync.")
                if let strongSelf = self, !strongSelf.isCancelled {
                    self?.newMessages = newMessages
                    self?.error = error
                }
                self?.finish()
            }
        } else {
            Analytics.trackBotSync()
            Bots.current.sync(queue: queue) { [weak self] (error, timeInterval, newMessages) in
                Analytics.trackBotDidSync(duration: timeInterval,
                                          numberOfMessages: newMessages,
                                          error: error)
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.info("SyncOperation finished with \(newMessages) new messages. Took \(timeInterval) seconds to sync.")
                if let strongSelf = self, !strongSelf.isCancelled {
                    self?.newMessages = newMessages
                    self?.error = error
                }
                self?.finish()
            }
        }
     }
     
    
}
