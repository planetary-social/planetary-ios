//
//  PostTextCache.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// An in-memory cache of `NSAttributedString` generated from
/// the entire `Post.text` markdown string.  This is suitable for use when
/// showing an entire post's content.
class PostTextCache: AttributedStringCache {

    @discardableResult
    func from(_ post: KeyValue) -> NSAttributedString {

        guard let innerPost = post.value.content.post else {
            assertionFailure("KeyValue is not a Post")
            return NSAttributedString(string: "KeyValue is not a Post")
        }

        return self.attributedString(for: post.key, markdown: innerPost.hasBlobs ? innerPost.text.withoutGallery() : innerPost.text)
    }

    override func invalidate() {
        Analytics.trackPurge(.text,
                             from: (count: self.count, numberOfBytes: self.estimatedBytes),
                             to: (count: 0, numberOfBytes: self.estimatedBytes))
        super.invalidate()
    }
}
