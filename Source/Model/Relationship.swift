//
//  Relationship.swift
//  Planetary
//
//  Created by Zef Houssney on 10/3/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import UIKit

/// Represents a relationship between two identities. To query the relationship between `identity` and `other`
/// instantiate a `Relationship` with them and call `load(reload:completion)`.
class Relationship: Sendable, Equatable {

    let identity: Identity
    let other: Identity

    var isFollowing = false

    var isFollowedBy = false

    var isFriend = false

    var isBlocking = false

    private var dataCached = false

    init(from identity: Identity, to other: Identity) {
        self.identity = identity
        self.other = other
    }

    func load(reload: Bool = false, completion: @escaping () -> Void) {
        if self.dataCached, !reload {
            completion()
            return
        }

        let group = DispatchGroup()

        group.enter()
        Bots.current.follows(identity: self.identity, queue: .main) { (contacts: [Identity], _) in
            self.isFollowing = contacts.contains(where: { $0 == self.other })
            group.leave()
        }

        group.enter()
        Bots.current.followedBy(identity: self.identity, queue: .main) { contacts, _ in
            self.isFollowedBy = contacts.contains(where: { $0 == self.other })
            group.leave()
        }

        group.enter()
        Bots.current.blocks(identity: self.identity, queue: .main) { contacts, _ in
            self.isBlocking = contacts.contains(where: { $0 == self.other })
            group.leave()
        }

        group.notify(queue: DispatchQueue.main) {
            self.dataCached = true
            completion()
        }
    }

    func reloadAndNotify() {
        self.load(reload: true) {
            self.notifyUpdate()
        }
    }

    var notificationName: Notification.Name {
        Notification.Name("Relationship-\(identity)-\(other)")
    }

    static var infoKey: String {
        String(describing: Self.self)
    }

    func notifyUpdate() {
        NotificationCenter.default.post(name: notificationName, object: nil, userInfo: [Relationship.infoKey: self])
    }

    func invalidateCache() {
        self.dataCached = false
    }

    static func == (lhs: Relationship, rhs: Relationship) -> Bool {
        lhs.identity == rhs.identity
        && lhs.other == rhs.other
        && lhs.isFollowing == rhs.isFollowing
        && lhs.isBlocking == rhs.isBlocking
        && lhs.isFollowedBy == rhs.isFollowedBy
    }
}

extension Notification {

    var relationship: Relationship? {
        self.userInfo?[Relationship.infoKey] as? Relationship
    }
}

extension Notification.Name {
    static let didUpdateRelationship = Notification.Name("didUpdateRelationship")
}
