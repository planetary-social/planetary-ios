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
}

extension Notification {

    var post: Post? {
        self.userInfo?["post"] as? Post
    }

    static func didPublishPost(_ post: Post) -> Notification {
        Notification(
            name: .didPublishPost,
            object: nil,
            userInfo: ["post": post]
        )
    }
}
