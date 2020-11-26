//
//  RedeemInviteOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

class RedeemInviteOperation: AsynchronousOperation {

    var star: Star
    private(set) var result: Result<Void, Error>?
    
    init(star: Star) {
        self.star = star
        super.init()
    }
    
    override func main() {
        Log.info("RedeemInviteOperation started.")
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            Log.info("Not logged in. RedeemInviteOperation finished.")
            self.result = .failure(BotError.notLoggedIn)
            self.finish()
            return
        }
        Log.debug("Redeeming invite to star \(self.star.feed)...")
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.inviteRedeem(queue: queue, token: self.star.invite) { [weak self, star] (error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            if let error = error {
                Log.info("RedeemInviteOperation to \(star.feed) finished with error \(error).")
                self?.result = .failure(error)
                self?.finish()
            } else {
                Log.debug("Publishing Contact (\(star.feed)) message...")
                let contact = Contact(contact: star.feed, following: true)
                Bots.current.publish(content: contact) { (_, error) in
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    if let error = error {
                        Log.info("RedeemInviteOperation to \(star.feed) finished with error \(error).")
                        self?.result = .failure(error)
                        self?.finish()
                    } else {
                        Log.debug("Publishing Pub (\(star.feed)) message...")
                        let pub = star.toPub()
                        Bots.current.publish(content: pub) { (_, error) in
                            Log.optional(error)
                            CrashReporting.shared.reportIfNeeded(error: error)
                            if let error = error {
                                Log.info("RedeemInviteOperation to \(star.feed) finished with error \(error).")
                                self?.result = .failure(error)
                                self?.finish()
                            } else {
                                Log.info("RedeemInviteOperation to \(star.feed) finished.")
                                self?.result = .success(())
                                self?.finish()
                            }
                        }
                    }
                }
            }
        }
    }
    
}
