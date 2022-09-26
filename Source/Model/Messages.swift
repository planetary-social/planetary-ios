//
//  Messages.swift
//  FBTT
//
//  Created by Christoph on 2/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias Messages = [Message]

// MARK: - Messages filtering

extension Messages {

    var contacts: Messages { self.filter(by: .contact) }
    var posts: Messages { self.filter(by: .post) }

    func filter(by type: ContentType) -> Messages {
        self.filter { $0.contentType == type }
    }

    // MARK: - Compound filters

    func rootPosts() -> Messages {
        self.filter { $0.contentType == .post && $0.value.content.post?.root == nil }
    }

    func replyPosts() -> Messages {
        self.filter { $0.contentType == .post && $0.value.content.post?.root != nil }
    }

    func mentions(of identity: Identity) -> Messages {
        self.filter { $0.value.content.post?.mentions?.contains { $0.link == identity } ?? false }
    }

    // MARK: - Trim by message identifier

    /// Returns a subarray from the 0th to the specified element,
    /// or empty array if the element was not found.  By default the
    /// element is NOT included in the sub array which is a slight
    /// difference from `Array.prefix(upTo)`.
    func prefix(upTo message: Message) -> Messages {
        guard let index = self.firstIndex(of: message) else { return [] }
        return Array(self.prefix(upTo: index))
    }

    /// Similar to `prefix(upTo message)` but is not inclusive.
    func prefix(before message: Message) -> Messages {
        guard var index = self.firstIndex(of: message) else { return [] }
        index = Swift.max(index - 1, 0)
        return Array(self.prefix(upTo: index))
    }

    /// Returns a subarray from the specified element to the end,
    /// or empty array if the element was not found.  By default the
    /// element is NOT included in the sub array which is a slight
    /// difference from `Array.suffix(from)`.
    func suffix(from message: Message) -> Messages {
        guard let index = self.firstIndex(of: message) else { return [] }
        return Array(self.suffix(from: index))
    }

    /// Similar to `suffix(from message)` but is not inclusive.
    func suffix(after message: Message) -> Messages {
        guard var index = self.firstIndex(of: message) else { return [] }
        index = Swift.min(index + 1, self.endIndex)
        return Array(self.suffix(from: index))
    }

    // MARK: - Filter by author

    func excluding(_ author: Identifier) -> Messages {
        self.filter { $0.value.author != author }
    }

    func only(from author: Identifier) -> Messages {
        self.filter { $0.value.author == author }
    }

    // MARK: - Messages sorting

    func sortedByDateAscending() -> Messages {
        self.sorted { $0.userDate < $1.userDate }
    }

    func sortedByDateDescending() -> Messages {
        self.sorted { $0.userDate > $1.userDate }
    }
}
