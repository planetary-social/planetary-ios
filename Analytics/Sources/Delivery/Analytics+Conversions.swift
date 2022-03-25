//
//  Analytics+Conversions.swift
//  
//
//  Created by Martin Dutra on 11/12/21.
//

import Foundation

public extension Analytics {

    func trackDidUpdateProfile() {
        service.track(event: .publish, element: .profile, name: "update")
    }

    func trackDidUpdateAvatar() {
        service.track(event: .publish, element: .profile, name: "avatar")
    }

    func trackDidFollowIdentity() {
        service.track(event: .publish, element: .identity, name: "follow")
    }

    func trackDidUnfollowIdentity() {
        service.track(event: .publish, element: .identity, name: "unfollow")
    }
    
    /// Should fire when a user follows or joins a pub.
    /// - Parameter multipeerAddress: the address of the pub in multipeer format.
    func trackDidJoinPub(at multipeerAddress: String) {
        service.track(event: .did, element: .action, name: "join_pub", params: ["address": multipeerAddress])
    }

    func trackDidBlockIdentity() {
        service.track(event: .publish, element: .identity, name: "block")
    }

    func trackDidUnblockIdentity() {
        service.track(event: .publish, element: .identity, name: "unblock")
    }

    func trackDidPost() {
        service.track(event: .publish, element: .post, name: "new")
    }

    func trackDidReply() {
        service.track(event: .publish, element: .post, name: "reply")
    }

}
