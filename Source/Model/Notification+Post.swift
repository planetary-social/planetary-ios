//
//  Notification+Post.swift
//  Planetary
//
//  Created by Martin Dutra on 30/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Notification.Name {
    static let didPublishPost = Notification.Name("didPublishPost")
    static let didPublishVote = Notification.Name("didPublishVote")
}

extension Notification {

    var post: Post? {
        self.userInfo?["post"] as? Post
    }

    var identifier: MessageIdentifier? {
        self.userInfo?["identifier"] as? MessageIdentifier
    }

    static func didPublishPost(_ post: Post) -> Notification {
        Notification(
            name: .didPublishPost,
            object: nil,
            userInfo: ["post": post]
        )
    }

    static func didPublishVote(to message: MessageIdentifier) -> Notification {
        Notification(
            name: .didPublishVote,
            object: nil,
            userInfo: ["identifier": message]
        )
    }
}
