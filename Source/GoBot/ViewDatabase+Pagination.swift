// Pagination for the ViewDatabase

import Foundation
import Logger

// the Int index might not be necessary but could be handy if one handler get's all the completions instead of
// individual UI elements
typealias PrefetchCompletion = (Int, Message) -> Void

/// An object that serves `Message`s. This proxy keeps a cache of `Message`s that are sometimes pre-fetched from a
/// slower database.
protocol PaginatedMessageDataProxy {
    /// The total number of messages in the view
    /// TODO: needs to be invalidated by insertLoop (maybe through notification center?)
    var count: Int { get }
    
    /// Fetches the `Message` at the given index.
    /// If the `Message` is in the cache, then it is returned immediately and `late` is not called.
    /// If the `Message` is not in the cache then `nil` is returned and the `late` block will be called later with
    /// the `Message`.
    func messageBy(index: Int, late: @escaping PrefetchCompletion) -> Message?
    
    /// Attempts to fetch the `Message` at the given index from this proxy's cache. If the `Message` is not in the
    /// cache then `nil` is returned.
    // TODO: i'm unable to make the above late: optional
    func messageBy(index: Int) -> Message?

    // notify the proxy to fetch more messages (up to and including index)
    func prefetchUpTo(index: Int)
}

// StaticDataProxy only has a fixed set of messages from the start and cant prefetch
class StaticDataProxy: PaginatedMessageDataProxy {
    let kvs: Messages
    let count: Int

    init() {
        self.kvs = []
        self.count = 0
    }

    init(with kvs: Messages) {
        self.kvs = kvs
        self.count = kvs.count
    }
    
    func messageBy(index: Int, late: @escaping PrefetchCompletion) -> Message? { self.kvs[index] }
    
    func messageBy(index: Int) -> Message? {
        if self.kvs.isEmpty {
            return nil
        } else {
            return self.kvs[index]
        }
    }

    func prefetchUpTo(index: Int) { /* noop */ }
}

class PaginatedPrefetchDataProxy: PaginatedMessageDataProxy {
    private let backgroundQueue = DispatchQueue(label: "planetary.view.prefetches") // simple, serial queue

    // store _late_ completions for when background finishes
    private let inflightSema = DispatchSemaphore(value: 1)
    private var inflight: [Int: [PrefetchCompletion]] = [:]

    // total number of messages that could be viewed
    let count: Int
    
    private var source: MessageSource
    private var msgs: [Message] = []
    
    init(with src: MessageSource) throws {
        self.source = src
        self.count = self.source.total
        self.msgs = try self.source.retreive(limit: 100, offset: 0)
        self.lastPrefetch = self.msgs.count
    }

    func messageBy(index: Int) -> Message? {
        if index >= self.count { return nil }
        guard index < self.msgs.count else { return nil }
        return self.msgs[index]
    }

    // we don't plan to spoort growing the backing list beyond it's initialisation
    func messageBy(index: Int, late: @escaping PrefetchCompletion) -> Message? {
        if index >= self.count { fatalError("FeedDataProxy #\(index) out-of-bounds") }
        if index > self.msgs.count - 1 {
            self.inflightSema.wait()
            var forIdx = self.inflight[index] ?? []
            if forIdx.isEmpty {
                prefetchUpTo(index: index)
            }
            forIdx.append(late)
            self.inflight[index] = forIdx // ?? needed?
            self.inflightSema.signal()
            return nil
        }
        return self.msgs[index]
    }
    
    // TODO: need to track the last range we fired a prefetch for
    // so that we can execute the next one for the correct window
    // if the user manages to trigger one while it is in flight
    // otherwise we get duplicated posts in the view

    private var lastPrefetch: Int
    
    func prefetchUpTo(index: Int) {
        // TODO: i think this might race without an extra lock...?
        guard index < self.count && index >= 0 else { fatalError("FeedDataProxy prefetch #\(index) out-of-bounds") }
        guard index > self.msgs.count - 1 else { return }

        self.backgroundQueue.asyncDeduped(target: self, after: 0.125) { [weak self] in
            guard let proxy = self else { return }

            // how many messages do we need?
            // +1 because we want fetch up to that index, not message count
            var diff = 1 + index - proxy.lastPrefetch
            if diff < 10 { // don't just do a little work
                diff = 25 // do a little extra
            }
            guard diff > 0 else { return }

            print("pre-fetching \(diff) messages current:\(proxy.lastPrefetch)")
            guard let moreMessages = try? proxy.source.retreive(limit: diff, offset: proxy.lastPrefetch) else {
                Log.unexpected(.botError, "failed to prefetch messages")
                return
            }
            // track the window so the next prefetch starts from where this ends
            proxy.lastPrefetch += diff

            // add new messages
            proxy.inflightSema.wait()
            proxy.msgs.append(contentsOf: moreMessages)
            let newCount = proxy.msgs.count

            // notify calls to messageBy that happend to soon
            for (idx, lateCompletions) in proxy.inflight {
                // handle calls to messageBy() for data right after the prefetch window
                if idx > newCount - 1 {
                    proxy.prefetchUpTo(index: idx)
                    print("WARNING: prefetching again for \(idx)!")
                    continue
                }
                let kv = proxy.msgs[idx]
                DispatchQueue.main.async { // update on main-thread or UI might get confused
                    for com in lateCompletions { com(idx, kv) }
                }
                proxy.inflight.removeValue(forKey: idx)
            }
            if moreMessages.count == 0 {
                print("expected to prefetch(\(diff):\(proxy.lastPrefetch - diff)) more messages but got none - clearning inflight")
                proxy.inflight = [:]
            }
            proxy.inflightSema.signal()
        }
    }
}

// MARK: sources

// abastract the data retreival for the proxy
protocol MessageSource {
    var total: Int { get }
    func retreive(limit: Int, offset: Int) throws -> [Message]
}

class RecentViewMessageSource: MessageSource {

    let view: ViewDatabase
    let total: Int

    // home or explore view?
    private let strategy: FeedStrategy

    init(with db: ViewDatabase, feedStrategy: FeedStrategy) throws {
        self.view = db

        self.strategy = feedStrategy
        self.total = try db.statsForRootPosts(strategy: strategy)
    }

    func retreive(limit: Int, offset: Int) throws -> [Message] {
        try self.view.recentPosts(strategy: strategy, limit: limit, offset: offset)
    }
}
