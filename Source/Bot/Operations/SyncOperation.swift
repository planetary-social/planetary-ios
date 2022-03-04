//
//  SyncOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 4/27/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Analytics

/// Pokes the bot into doing a sync. Don't use this SyncOperation directly, use
/// SendMissionOperation instead.
class SyncOperation: AsynchronousOperation {
    
    /// List of available peers to establish connection
    var peers: [Peer]
    
    /// If true, only will sync to one peer with no retries
    var notificationsOnly: Bool = false
    
    /// Number of new messages available in the repo after the sync
    private(set) var newMessages: Int = 0
    
    private(set) var error: Error?
    
    init(peers: [Peer]) {
        self.peers = peers
        super.init()
    }
     
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
        if self.notificationsOnly {
            Bots.current.syncNotifications(queue: queue, peers: peers) { [weak self] (error, timeInterval, newMessages) in
                Analytics.shared.trackBotDidSync(duration: timeInterval,
                                          numberOfMessages: newMessages)
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
            Bots.current.sync(queue: queue, peers: peers) { [weak self] (error, timeInterval, newMessages) in
                Analytics.shared.trackBotDidSync(duration: timeInterval,
                                          numberOfMessages: newMessages)
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
