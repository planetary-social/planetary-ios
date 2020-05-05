// Pagination for the ViewDatabase

import Foundation


// the Int index might not be nescessary but could be handy if one handler get's all the completions instead of individual UI elements
typealias PrefetchCompletion = (Int, KeyValue) -> Void

protocol PaginatedKeyValueDataProxy {
    // the total number of messages in the view
    // TODO: needs to be invalidated by insertLoop (maybe through notification center?)
    var count: Int { get }
    
    // late get's called with the KeyValue if prefetch didn't finish in time
    func keyValueBy(index: Int, late: @escaping PrefetchCompletion) -> KeyValue?
    
    // TODO: i'm unable to make the above late: optional
    func keyValueBy(index: Int) -> KeyValue?

    // notify the proxy to fetch more messages (up to and including index)
    func prefetchUpTo(index: Int) -> Void
}

class StaticDataProxy: PaginatedKeyValueDataProxy {
    let kvs: KeyValues
    let count: Int

    init() {
        self.kvs = []
        self.count = 0
    }

    init(with kvs: KeyValues) {
        self.kvs = kvs
        self.count = kvs.count
    }
    
    func keyValueBy(index: Int, late: @escaping PrefetchCompletion) -> KeyValue? { return self.kvs[index] }
    
    func keyValueBy(index: Int) -> KeyValue? { return self.kvs[index] }

    func prefetchUpTo(index: Int) { /* noop */ }
}

extension ViewDatabase {
    // returns a pagination proxy for the home (or recent) view
    func paginated() throws -> (PaginatedKeyValueDataProxy) {
        let src = try RecentViewKeyValueSource(with: self)
        return try PaginatedFeedDataProxy(with: src)
    }

    func paginated(thread msg: MessageIdentifier) throws -> (PaginatedKeyValueDataProxy) {
        guard msg.isValidIdentifier else { throw GoBotError.unexpectedFault("invalid message identifier")}
        throw GoBotError.unexpectedFault("TODO:paginated thread")
    }

    func paginated(feed: Identity) throws -> (PaginatedKeyValueDataProxy) {
        let src = try FeedKeyValueSource(with: self, feed: feed)
        return try PaginatedFeedDataProxy(with: src)
    }
}

// abastract the data retreival for the proxy
protocol KeyValueSource {
    var total: Int { get }
    func retreive(limit: Int, offset: Int) throws -> [KeyValue]
}

class RecentViewKeyValueSource: KeyValueSource {
    let view: ViewDatabase

    let total: Int

    init(with vdb: ViewDatabase) throws {
        self.view = vdb
        self.total = try vdb.statsForRootPosts(onlyFollowed: true)
    }

    func retreive(limit: Int, offset: Int) throws -> [KeyValue] {
        return try self.view.recentPosts(limit: limit, offset: offset)
    }
}

class FeedKeyValueSource: KeyValueSource {
    let view: ViewDatabase
    let feed: FeedIdentifier

    let total: Int

    init(with vdb: ViewDatabase, feed: FeedIdentifier) throws {
        self.view = vdb

        guard feed.isValidIdentifier else { fatalError("invalid feed handle: \(feed)") }
        self.feed = feed

        self.total = try self.view.stats(for: self.feed)
    }

    func retreive(limit: Int, offset: Int) throws -> [KeyValue] {
        return try self.view.feed(for: self.feed, limit: limit, offset: offset)
    }
}

class PaginatedFeedDataProxy: PaginatedKeyValueDataProxy {
    private let backgroundQueue = DispatchQueue.global(qos: .userInitiated)

    // store _late_ completions for when background finishes
    private let inflightSema = DispatchSemaphore(value: 1)
    private var inflight: [Int: [PrefetchCompletion]] = [:]

    // total number of messages that could be viewed
    let count: Int
    
    private var source: KeyValueSource
    private var msgs: [KeyValue] = []
    
    init(with src: KeyValueSource) throws {
        self.source = src
        self.count = self.source.total
        self.msgs = try self.source.retreive(limit: 10, offset: 0)
    }

    func keyValueBy(index: Int) -> KeyValue? {
        if index >= self.count { fatalError("FeedDataProxy out-of-bounds") }
        guard index < self.msgs.count else { return nil }
        return self.msgs[index]
    }

    func keyValueBy(index: Int, late: @escaping PrefetchCompletion) -> KeyValue? {
        if index >= self.count { fatalError("FeedDataProxy out-of-bounds") }
        if index > self.msgs.count-1 {
            self.inflightSema.wait()
            var forIdx = self.inflight[index] ?? []
            forIdx.append(late)
            self.inflight[index] = forIdx // ?? needed?
            self.inflightSema.signal()
            return nil
        }
        return self.msgs[index]
    }
    
    func prefetchUpTo(index: Int) {
        // TODO: i think this might race without an extra lock...?
        guard index > self.msgs.count-1 else { return }

        self.backgroundQueue.asyncDeduped(target: self, after: 0.125) { [weak self] in
            guard let proxy = self else { return }

            // how many messages do we have
            let current = proxy.msgs.count

            // how many messages do we need?
            // +1 because we want fetch up to that index, not message count
            var diff = 1+index - current
            if diff < 10 { // don't just do a little work
                diff = 25 // do a little extra
            }

            print("pre-fetching \(diff) messages current:\(current)")
            guard let moreMessages = try? proxy.source.retreive(limit: diff, offset: current) else {
                Log.unexpected(.botError, "failed to prefetch messages")
                return
            }

            // add new messages
            proxy.inflightSema.wait()
            proxy.msgs.append(contentsOf: moreMessages)
            let newCount = proxy.msgs.count

            // notify calls to keyValueBy that happend to soon
            for (idx, lateCompletions) in proxy.inflight {
                if idx > newCount-1 { // handle calls to keyValueBy() for data right after the prefetch window
                    proxy.prefetchUpTo(index: idx)
                    continue
                }
                let kv = proxy.msgs[idx]
                DispatchQueue.main.async { // update on main-thread or UI might get confused
                    for com in lateCompletions { com(idx, kv) }
                }
                proxy.inflight.removeValue(forKey: idx)
            }
            proxy.inflight = [:]
            proxy.inflightSema.signal()
        }
    }
}
