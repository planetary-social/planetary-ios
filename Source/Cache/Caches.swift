//
//  Caches.swift
//  Planetary
//
//  Created by Christoph on 11/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Caches {

    static let blobs = BlobCache()
    static let text = PostTextCache()
    static let truncatedText = PostTruncatedTextCache()

    static func invalidate() {
        self.blobs.invalidate()
        self.text.invalidate()
        self.truncatedText.invalidate()
    }
}
