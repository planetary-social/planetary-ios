//
//  RedeemInviteOperation.swift
//  Planetary
//
//  Created by Martin Dutra on 8/12/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Network
import Logger
import CrashReporting
import Analytics

class RedeemInviteOperation: AsynchronousOperation {

    /// Star that you want to redeem invitation to
    var star: Star
    
    /// If true, it will automatically follow the star
    var shouldFollow: Bool
    
    /// Result of the operation
    private(set) var result: Result<Void, Error>?
    
    init(star: Star, shouldFollow: Bool) {
        self.star = star
        self.shouldFollow = shouldFollow
        super.init()
    }
    
    override func main() {
        Log.info("RedeemInviteOperation started.")
        
        redeemInvitation { result in
            
            switch result {
            case .success:
                self.result = .success(())
                self.finish()
                
            case .failure(let error):
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                // Construct a better error message before returning
                Bots.current.about(identity: self.star.feed) { about, _ in
                    let starName = about?.name ?? self.star.feed
                    let localizedMessage = Localized.Error.invitationRedemptionFailed.text(["starName": starName])
                    let userError = NSError(
                        domain: String(describing: type(of: self)),
                        code: 0,
                        userInfo: [NSLocalizedDescriptionKey: localizedMessage]
                    )
                    
                    self.result = .failure(userError)
                    self.finish()
                }
            }
        }
    }
        
    private func redeemInvitation(completion: @escaping (Result<Void, Error>) -> Void) {
        
        let configuredIdentity = AppConfiguration.current?.identity
        let loggedInIdentity = Bots.current.identity
        guard loggedInIdentity != nil, loggedInIdentity == configuredIdentity else {
            completion(.failure(BotError.notLoggedIn))
            return
        }
        Log.debug("Redeeming invite to star \(self.star.feed)...")
        let queue = OperationQueue.current?.underlyingQueue ?? DispatchQueue.global(qos: .background)
        Bots.current.redeemInvitation(to: star, completionQueue: queue) { [star, shouldFollow] (error) in
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            guard error == nil else {
                completion(.failure(error!))
                return
            }
            
            Log.debug("Publishing Pub (\(star.feed)) message...")
            let pub = star.toPub()
            Bots.current.publish(content: pub) { (_, error) in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                if let error = error {
                    Log.info("Publishing Pub \(star.feed) message finished with error \(error).")
                    // We don't care the result, move on
                }
                if shouldFollow {
                    Log.debug("Publishing Contact (\(star.feed)) message...")
                    let contact = Contact(contact: star.feed, following: true)
                    Bots.current.publish(content: contact) { (_, error) in
                        guard error == nil else {
                            completion(.failure(error!))
                            return
                        }
                        
                        Analytics.shared.trackDidFollowPub()
                        
                        completion(.success(()))
                    }
                } else {
                    completion(.success(()))
                }
            }
        }
    }
}
