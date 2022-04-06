//
//  Onboarding+Follow.swift
//  FBTT
//
//  Created by Christoph on 5/30/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// TODO should these be declared inside Onboarding?
// TODO or should the completions be generic?
typealias FollowCompletion = ((Bool, [Contact], [Error]) -> Void)
typealias PubInviteCompletion = ((Bool, OnboardingError?) -> Void)
typealias OnboardingCompletion = ((Bool, OnboardingError?) -> Void)

extension Onboarding {

    static func follow(_ identities: [Identity],
                       context: Context,
                       completion: @escaping FollowCompletion) {
        guard identities.count > 0 else { completion(true, [], []); return }

        var contacts: [Contact] = []
        var errors: [Error] = []

        for identity in identities {
            context.bot.follow(identity) {
                contact, error in
                if let contact = contact { contacts += [contact] }
                if let error = error { errors += [error] }
                if contacts.count + errors.count == identities.count {
                    let success = contacts.count == identities.count
                    completion(success, contacts, errors)
                }
            }
        }
    }

    // TODO analytics
    static func invitePubsToFollow(_ identity: Identity,
                                  completion: @escaping ((Bool, Error?) -> Void)) {
        guard identity.isValidIdentifier else {
            completion(false, OnboardingError.invalidIdentity(identity))
            return
        }
        // TODO: this code is not run during APITests but should be called in test40_invite_pubs https://app.asana.com/0/0/1134329918920786/f
        PubAPI.shared.invitePubsToFollow(identity) { success, error in
            completion(success, error)
        }
    }
}
