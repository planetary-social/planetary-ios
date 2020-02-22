//
//  PostTruncatedTextTableViewDataSourcePrefetching.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

class PostReplyDataSourcePrefetching: KeyValueTableViewDataSourcePrefetching {

    override func prefetchRows(withKeyValues keyValues: KeyValues) {
        let posts = keyValues.filter(by: .post)
        Caches.truncatedText.prefill(posts)
    }

    override func cancelPrefetchingForRows(withKeyValues keyValues: KeyValues) {
        let posts = keyValues.filter(by: .post)
        let keys = posts.map { $0.key }
        Caches.truncatedText.cancel(markdownsWithKeys: keys)
    }
}
