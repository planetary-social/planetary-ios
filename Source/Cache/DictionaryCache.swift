//
//  DictionaryCache.swift
//  Planetary
//
//  Created by Christoph on 11/20/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class DictionaryCache: Cache {

    private var dictionary: [String: (Date, Any)] = [:]

    var count: Int {
        Thread.assertIsMainThread()
        return self.dictionary.count
    }

    var estimatedBytes: Int {
        Thread.assertIsMainThread()
        var bytes = 0
        self.dictionary.forEach {
            bytes += self.bytes(for: $0.value.1)
        }
        return bytes
    }

    func bytes(for item: Any) -> Int {
        Thread.assertIsMainThread()
        // subclasses should implement
        return 0
    }

    /// Returns the cache item by key.  If the item cannot be found, nil is returned.
    /// If the item is found, the current `TimeInterval` is updated for that item.
    /// This allows `purge()` to correctly clean up items.
    func item(for key: String) -> Any? {
        Thread.assertIsMainThread()
        guard let (_, item) = self.dictionary[key] else { return nil }
        self.update(item, for: key)
        return item
    }

    func itemsSortedByDateAscending() -> [(key: String, value: (Date, Any))] {
        Thread.assertIsMainThread()
        let items = self.dictionary.sorted {
            (first: (key: String, value: (Date, Any)), second: (key: String, value: (Date, Any))) in
            first.value.0 < second.value.0
        }
        return items
    }

    internal func update(_ item: Any, for key: String) {
        Thread.assertIsMainThread()
        self.dictionary[key] = (Date(), item)
    }

    func purge() {
        // subclasses should implement
    }

    func invalidate() {
        Thread.assertIsMainThread()
        self.dictionary.removeAll()
    }

    func invalidateItem(for key: String) {
        Thread.assertIsMainThread()
        self.dictionary.removeValue(forKey: key)
    }
}
