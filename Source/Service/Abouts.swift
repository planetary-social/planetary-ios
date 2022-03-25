//
//  Abouts.swift
//  FBTT
//
//  Created by Christoph on 6/18/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

// TODO https://app.asana.com/0/914798787098068/1121081744093372/f
// this should become part of Caches.mentions.recent
struct AboutService {

    private static var identities: [Identity] = []

    /// Adds the specified identity to the of a stack representing
    /// recently mentioned identities.  This is used to populate the
    /// input identities for matching() without a filter string value.
    static func didMention(_ identity: Identity) {
        guard self.identities.contains(identity) == false else { return }
        var identities = self.identities
        identities.insert(identity, at: 0)
        self.identities = Array(identities.prefix(5))
    }

    static func matching(_ string: String? = nil,
                         completion: @escaping AboutsCompletion) {
        // return abouts for recent mentions
        let useRecent = (string?.isEmpty ?? true) && self.identities.count > 0
        if useRecent {
            self.sortedAbouts(for: self.identities, filteredBy: string) {
                abouts, _ in
                completion(abouts, nil)
            }
            return
        }

        // otherwise return abouts for my network
        self.network {
            identities, _ in
            self.sortedAbouts(for: identities, filteredBy: string) {
                abouts, _ in
                completion(abouts, nil)
            }
        }
    }

    /// IMPORTANT!
    /// This will likely be performed on the main thread, so if the
    /// identities array is very large this could be a bottleneck.
    private static func sortedAbouts(for identities: [Identity],
                                     filteredBy string: String?,
                                     completion: @escaping AboutsCompletion) {
        Bots.current.abouts(identities: identities) {
            abouts, error in
            guard let string = string else { completion(abouts.sorted(), error); return }
            guard string.isEmpty == false else { completion(abouts.sorted(), error); return }
            let filtered = abouts.filter { $0.contains(string) }
            completion(filtered.sorted(), nil)
        }
    }

    // TODO move to Bot+Me extension for logged in identity specific calls
    private static func network(completion: @escaping ContactsCompletion) {
        assert(Thread.isMainThread)

        // TODO Bot should have a "me" version
        guard let identity = Bots.current.identity else {
            completion([], BotError.notLoggedIn)
            return
        }

        var identities: Set<Identity> = Set()
        let group = DispatchGroup()

        group.enter()
        Bots.current.follows(identity: identity) { (contacts: [Identity], _) in
            identities = identities.union(Set<Identity>(contacts))
            group.leave()
        }

        group.enter()
        Bots.current.followedBy(identity: identity) {
            contacts, _ in
            identities = identities.union(Set<Identity>(contacts))
            group.leave()
        }

        group.notify(queue: DispatchQueue.main) {
            completion(Array(identities), nil)
        }
    }
}
