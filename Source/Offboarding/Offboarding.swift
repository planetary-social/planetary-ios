//
//  Offboarding.swift
//  Planetary
//
//  Created by Christoph on 12/11/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

enum OffboardingError: Error {
    case apiError(Error)
    case botError(Error)
    case invalidConfiguration
    case invalidIdentity
    case mustBeLoggedIn
    case other(Error?)
}

class Offboarding {

    typealias Completion = ((OffboardingError?) -> Void)

    static func offboard(completion: @escaping Completion)
    {
        guard let identity = Bots.current.identity else { completion(.mustBeLoggedIn); return }
        guard let configuration = AppConfiguration.current else { completion(.invalidConfiguration) ; return }
        guard configuration.identity == identity else { completion(.invalidIdentity); return }

        Analytics.shared.trackOffboardingStart()

        // unfollow all
        // errors not allowed
        Offboarding.unfollowAllFollowedBy(identity) {
            error in
            if let error = error { completion(.botError(error)); return }

            // log out
            // errors not allowed
            Bots.current.logout {
                error in
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                
                if let error = error { completion(.botError(error)); return }
                
                // remove configuration
                configuration.unapply()
                AppConfigurations.delete(configuration)

                // done
                Analytics.shared.trackOffboardingEnd()
                Analytics.shared.forget()
                
                completion(nil)
            }
        }
    }

    // TODO move to Bot+Unfollow
    private static func unfollowAllFollowedBy(_ identity: Identity,
                                              completion: @escaping ((Error?) -> Void))
    {
        // identities following this identity
        Bots.current.follows(identity: identity) { (identities: [Identity], error) in
            if let error = error { completion(error); return }
            if identities.isEmpty { completion(nil); return }

            // unfollow each identity
            // use a dispatch group to do serially
            var unfollowError: Error?
            let group = DispatchGroup()
            for identity in identities {
                group.enter()
                DispatchQueue.main.async(group: group) {
                    Bots.current.unfollow(identity) {
                        _, error in
                        if let error = error { unfollowError = error }
                        group.leave()
                    }
                }
            }

            // TODO error?
            group.notify(queue: DispatchQueue.main) {
                completion(unfollowError)
            }
        }
    }
}
