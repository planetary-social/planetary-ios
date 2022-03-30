//
//  AttributedStringCache.swift
//  FBTT
//
//  Created by Christoph on 6/23/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

class AttributedStringCache: DictionaryCache {

    private let maxNumberOfItems = Int(100)
    private let minNumberOfItems = Int(50)

    @discardableResult
    func attributedString(for key: String,
                          markdown: String) -> NSAttributedString {
        Thread.assertIsMainThread()

        // cached value if possible
        if let string = self.item(for: key) as? NSAttributedString {
            return string
        }

        // generate and cache
        let string = NSMutableAttributedString(attributedString: markdown.decodeMarkdown())
        self.update(string, for: key)
        self.purge()
        return string
    }

    /// Returns -1 indicating that this cache does not purge based on bytes used.
    /// It's more because I can't figure out a good way to estimated the number of
    /// bytes used in an `NSAttributedString` so...
    override var estimatedBytes: Int {
        -1
    }

    /// Invalidates the oldest items beyond the `maxNumberOfItems`.
    override func purge() {
        Thread.assertIsMainThread()
        guard self.count > self.maxNumberOfItems else { return }
        let items = self.itemsSortedByDateAscending()
        let itemsToInvalidate = items[self.minNumberOfItems ..< items.endIndex]
        let keys = itemsToInvalidate.compactMap { $0.key }
        keys.forEach { self.invalidateItem(for: $0) }
    }

    /// Invalidates the entire cache and cancels all pending prefills.
    override func invalidate() {
        super.invalidate()
        self.cancel()
    }

    // MARK: Asynchronous pre-fill

    /// A local queue to render markdown and cache in advance.  The
    /// `prefill()` and `cancel()` funcs can only be called from
    /// the main thread.
    private let queue = DispatchQueue(label: "AttributedStringCache",
                                      qos: .userInitiated,
                                      attributes: .concurrent,
                                      autoreleaseFrequency: .workItem,
                                      target: nil)

    /// A serial queue of keys and markdowns to render.  This is implemented as
    /// an array for simplicity, and is suitable for dozens of items.  If the needs are
    /// in the hundreds, then another should be used.
    typealias KeyMarkdown = (key: String, markdown: String)
    private var array: [KeyMarkdown] = []
    private var current: KeyMarkdown?

    /// The number of markdowns in the pre-fill queue.
    var prefillCount: Int {
        Thread.assertIsMainThread()
        return self.array.count
    }

    /// Adds the specified keys and markdowns to the queue of prefills.  This adds to
    /// the end of the FIFO queue, so previous renders will have to be executed or
    /// cancelled before new ones are executed.  If any of the markdowns already
    /// exist in the cache, they are filtered out first.
    func prefill(_ markdowns: [KeyMarkdown]) {
        Thread.assertIsMainThread()
        let filtered = markdowns.filter { self.item(for: $0.key) == nil }
        guard filtered.count > 0 else { return }
        self.array += filtered
        self.next()
    }

    /// If a render is not already in progress, starts the process.  This will
    /// kick the local queue to start rendering, and caches the results when
    /// complete.  The next render will be started if necessary.  Note that
    /// the queue operates as a FIFO serial queue, rendering the oldest
    /// item first, and once at a time.  This is reduce how much memory might
    /// be needed for whatever markdown utility is being used.
    private func next() {

        guard self.current == nil else { return }
        guard self.array.count > 0 else { return }

        self.current = self.array.first
        let current = self.array.removeFirst()

        self.queue.async {
            let string = current.markdown.decodeMarkdown()
            DispatchQueue.main.async {
                self.current = nil
                self.update(string, for: current.key)
                self.purge()
                self.next()
            }
        }
    }

    /// Cancels pending markdowns by key.
    func cancel(markdownsWithKeys keys: [String]) {
        Thread.assertIsMainThread()
        guard self.array.count > 0 else { return }
        for key in keys { self.array.removeAll { $0.key == key } }
    }

    /// Cancels all pending markdown renders, except for the one in progress.
    func cancel() {
        Thread.assertIsMainThread()
        self.array.removeAll()
    }
}
