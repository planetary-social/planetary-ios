//
//  AnalyticsService+Conversions.swift
//  Planetary
//
//  Created by Martin Dutra on 5/5/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

extension AnalyticsService {
    
    func trackDidUpdateProfile() {
        self.track(event: .publish, element: .profile, name: "update")
    }
    
    func trackDidUpdateAvatar() {
        self.track(event: .publish, element: .profile, name: "avatar")
    }
    
    func trackDidFollowIdentity() {
        self.track(event: .publish, element: .identity, name: "follow")
    }
    
    func trackDidUnfollowIdentity() {
        self.track(event: .publish, element: .identity, name: "unfollow")
    }
    
    func trackDidBlockIdentity() {
        self.track(event: .publish, element: .identity, name: "block")
    }
    
    func trackDidUnblockIdentity() {
        self.track(event: .publish, element: .identity, name: "unblock")
    }
    
    func trackDidPost() {
        self.track(event: .publish, element: .post, name: "new")
    }
    
    func trackDidReply() {
        self.track(event: .publish, element: .post, name: "reply")
    }
    
}
