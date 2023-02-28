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
    
    func trackDidFollowPub() {
        service.track(event: .publish, element: .identity, name: "follow_pub")
    }

    func trackDidUnfollowIdentity() {
        service.track(event: .publish, element: .identity, name: "unfollow")
    }
    
    /// Should fire when a user follows or joins a pub.
    /// - Parameter multipeerAddress: the address of the pub in multipeer format.
    func trackDidJoinPub(at multiPeerAddress: String) {
        service.track(event: .did, element: .action, name: "join_pub", params: ["address": multiPeerAddress])
    }
    
    func trackDidJoinRoom(at multiPeerAddress: String) {
        service.track(event: .did, element: .action, name: "join_room", params: ["address": multiPeerAddress])
    }
    
    func trackDidRegister(alias: String, in multiPeerAddress: String) {
        let params = ["address": multiPeerAddress, "alias": alias]
        service.track(event: .did, element: .action, name: "register_alias", params: params)
    }

    func trackDidBlockIdentity() {
        service.track(event: .publish, element: .identity, name: "block")
    }

    func trackDidUnblockIdentity() {
        service.track(event: .publish, element: .identity, name: "unblock")
    }

    func trackDidPost(characterCount: Int) {
        service.track(event: .publish, element: .post, name: "new", param: "post_length", value: "\(characterCount)")
    }

    func trackDidReply(characterCount: Int) {
        service.track(event: .publish, element: .post, name: "reply", param: "reply_length", value: "\(characterCount)")
    }
}
