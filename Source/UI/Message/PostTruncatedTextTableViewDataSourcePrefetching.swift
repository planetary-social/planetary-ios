//
//  PostTruncatedTextTableViewDataSourcePrefetching.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class PostReplyDataSourcePrefetching: MessageTableViewDataSourcePrefetching {

    override func prefetchRows(withMessages messages: Messages) {
        let posts = messages.filter(by: .post)
        Caches.truncatedText.prefill(posts)
    }

    override func cancelPrefetchingForRows(withMessages messages: Messages) {
        let posts = messages.filter(by: .post)
        let keys = posts.map { $0.key }
        Caches.truncatedText.cancel(markdownsWithKeys: keys)
    }
}
