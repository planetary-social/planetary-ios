//
//  KeyValues.swift
//  FBTT
//
//  Created by Christoph on 2/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias KeyValues = [KeyValue]

// MARK: - KeyValues filtering

extension KeyValues {

    var contacts: KeyValues { self.filter(by: .contact) }
    var posts: KeyValues { self.filter(by: .post) }

    func filter(by type: ContentType) -> KeyValues {
        self.filter { $0.contentType == type }
    }
}

// MARK: - Compound filters

extension KeyValues {

    func rootPosts() -> KeyValues {
        self.filter { $0.contentType == .post && $0.value.content.post?.root == nil }
    }

    func replyPosts() -> KeyValues {
        self.filter { $0.contentType == .post && $0.value.content.post?.root != nil }
    }

    func mentions(of identity: Identity) -> KeyValues {
        self.filter { $0.value.content.post?.mentions?.contains { $0.link == identity } ?? false }
    }
}

// MARK: - Trim by message identifier

extension KeyValues {

    /// Returns a subarray from the 0th to the specified element,
    /// or empty array if the element was not found.  By default the
    /// element is NOT included in the sub array which is a slight
    /// difference from `Array.prefix(upTo)`.
    func prefix(upTo keyValue: KeyValue) -> KeyValues {
        guard let index = self.firstIndex(of: keyValue) else { return [] }
        return Array(self.prefix(upTo: index))
    }

    /// Similar to `prefix(upTo keyValue)` but is not inclusive.
    func prefix(before keyValue: KeyValue) -> KeyValues {
        guard var index = self.firstIndex(of: keyValue) else { return [] }
        index = Swift.max(index - 1, 0)
        return Array(self.prefix(upTo: index))
    }

    /// Returns a subarray from the specified element to the end,
    /// or empty array if the element was not found.  By default the
    /// element is NOT included in the sub array which is a slight
    /// difference from `Array.suffix(from)`.
    func suffix(from keyValue: KeyValue) -> KeyValues {
        guard let index = self.firstIndex(of: keyValue) else { return [] }
        return Array(self.suffix(from: index))
    }

    /// Similar to `suffix(from keyValue)` but is not inclusive.
    func suffix(after keyValue: KeyValue) -> KeyValues {
        guard var index = self.firstIndex(of: keyValue) else { return [] }
        index = Swift.min(index + 1, self.endIndex)
        return Array(self.suffix(from: index))
    }
}

// MARK: - Filter by author

extension KeyValues {

    func excluding(_ author: Identifier) -> KeyValues {
        self.filter { $0.value.author != author }
    }

    func only(from author: Identifier) -> KeyValues {
        self.filter { $0.value.author == author }
    }
}

// MARK: - KeyValues sorting

extension KeyValues {

    func sortedByDateAscending() -> KeyValues {
        self.sorted { $0.userDate < $1.userDate }
    }

    func sortedByDateDescending() -> KeyValues {
        self.sorted { $0.userDate > $1.userDate }
    }
}
