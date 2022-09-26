//
//  PostTruncatedTextCache.swift
//  Planetary
//
//  Created by Christoph on 12/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// An in-memory cache of `NSAttributedString` generated from truncated
/// `Post.text` markdown.  This different than `PostTextCache` which is
/// the full text, not truncated.  Note that the values between the two caches are NOT
/// shared because they will likely be styled aka "attributed" differently.
///
/// This is suitable for showing truncated post content, like on the Home screen.
class PostTruncatedTextCache: AttributedStringCache {

    /// If the truncated length is too close to the actual length of
    /// the string, then there is not much point in truncating it.  Use
    /// the two values to determine when truncation should happen.
    /// Be aware of how these values will affect `NSAttributedString.TruncationSettings`.
    /// If the truncation setting limit is too high, then the string will be
    /// shown without a See More.
    private let truncationLength = Int(600)
    private let lengthToTruncate = Int(700)

    @discardableResult
    func from(_ kv: Message) -> NSAttributedString {

        guard let post = kv.value.content.post else {
            assertionFailure("Message is not a Post")
            return NSAttributedString(string: "Message is not a Post")
        }

        // truncate the text and generate the string
        // one optimization would be to check the cache
        // before bothering to truncate the text
        let truncated = self.truncate(post.hasBlobs ? post.text.withoutGallery() : post.text)
        return self.attributedString(for: kv.key, markdown: truncated)
    }

    /// Returns the original string or a truncated version based on the configured
    /// `truncationLength` and `lengthToTruncate`.  The lengths are
    /// overlapping so ensure that a string is sufficiently long enough past the minimum
    /// that truncating won't impact layout.
    private func truncate(_ markdown: String) -> String {
        if markdown.count > self.lengthToTruncate {
            return String(markdown.prefix(self.truncationLength))
        } else {
            return markdown
        }
    }

    /// Convenience func to transform an array of `Post` into the
    /// lower level `KeyMarkdown`.
    func prefill(_ posts: Messages) {
        let markdowns: [KeyMarkdown] = posts.compactMap {
            guard let post = $0.value.content.post else { return nil }
            let truncated = self.truncate(post.hasBlobs ? post.text.withoutGallery() : post.text)
            return (key: $0.key, markdown: truncated)
        }
        self.prefill(markdowns)
    }

    override func invalidate() {
        Log.info("Purging with count=\(self.count), estimatedBytes=\(self.estimatedBytes)")
        super.invalidate()
    }
}
