//
//  FakeBot.swift
//  FBTT
//
//  Created by Christoph on 2/6/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

enum FakeBotError: Error {
    case runtimeError(String)
}

class FakeBot: Bot {
    
    required init(userDefaults: UserDefaults, preloadedPubService: PreloadedPubService?) {}
    
    func lastReceivedTimestam() throws -> Double { 0 }
    
    func suspend() { }
    
    func exit() { }
    
    func reports(queue: DispatchQueue, completion: @escaping (([Report], Error?) -> Void)) {
        queue.async {
            completion([], nil)
        }
    }
    
    func seedPubAddresses(
        addresses: [PubAddress],
        queue: DispatchQueue,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        queue.async {
            completion(.success(()))
        }
    }
    
    func knownPubs(completion: @escaping KnownPubsCompletion) { }
    
    func joinedPubs(queue: DispatchQueue, completion: @escaping (([Pub], Error?) -> Void)) {
        queue.async {
            completion([], nil)
        }
    }
    func redeemInvitation(to: Star, completionQueue: DispatchQueue, completion: @escaping ErrorCompletion) {
        completionQueue.async { completion(nil) }
    }
    
    func thread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) { }

    func updateReceive(limit: Int, completion: @escaping PublishCompletion) { }
    
    func addBlob(data: Data, completion: @escaping BlobsAddCompletion) { }

    func addBlob(jpegOf image: UIImage, largestDimension: UInt?, completion: @escaping AddImageCompletion) { }
    
    func store(url: URL, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion) { }
    
    func store(data: Data, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion) { }

    func data(for identifier: BlobIdentifier, completion: @escaping ((BlobIdentifier, Data?, Error?) -> Void)) { }

    func hashtags(completion: @escaping HashtagsCompletion) { }

    func hashtags(usedBy identity: Identity, limit: Int, completion: @escaping HashtagsCompletion) { }

    func posts(with hashtag: Hashtag, completion: @escaping PaginatedCompletion) { }

    func uiimage(for identity: Identity, completion: @escaping UIImageCompletion) { }
    
    func uiimage(for image: ImageMetadata, completion: @escaping UIImageCompletion) { }

    func publish(content: ContentCodable, completionQueue: DispatchQueue, completion: @escaping PublishCompletion) {
        completionQueue.async {
            completion(MessageIdentifier.null, nil)
        }
    }

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion) { }

    func update(message: MessageIdentifier, content: ContentCodable, completion: @escaping ErrorCompletion) { }
    
    func follows(identity: Identity, completion: @escaping ContactsCompletion) { }
    
    func followers(identity: Identity, queue: DispatchQueue, completion: @escaping AboutsCompletion) { }
    
    func followedBy(identity: Identity, completion: @escaping ContactsCompletion) { }

    func followings(identity: Identity, queue: DispatchQueue, completion: @escaping AboutsCompletion) { }
    
    func friends(identity: Identity, completion: @escaping ContactsCompletion) { }

    func socialStats(for identity: Identity, completion: @escaping ((SocialStats, Error?) -> Void)) { }
    
    func blocks(identity: Identity, completion: @escaping ContactsCompletion) { }
    
    func blockedBy(identity: Identity, completion: @escaping ContactsCompletion) { }

    func block(_ identity: Identity, completion: @escaping PublishCompletion) { }

    func unblock(_ identity: Identity, completion: @escaping PublishCompletion) { }

    func follow(_ identity: Identity, completion: @escaping ContactCompletion) { }

    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion) { }

    required init() {}
    static let shared = FakeBot()

    // MARK: Name

    let name = "FakeBot"
    let version = "1.0"
    let logFileUrls: [URL] = []
    
    // MARK: Login
    private var _network: String?
    private var _identity: Identity?
    var identity: Identity? { self._identity }

    func createSecret(completion: SecretCompletion) {
        completion(nil, FakeBotError.runtimeError("TODO:createSecret"))
    }

    func login(queue: DispatchQueue, config: AppConfiguration, completion: @escaping ErrorCompletion) {
        self._network = config.network?.string
        self._identity = config.secret.identity
        queue.async {
            completion(nil)
        }
    }

    func logout(completion: ErrorCompletion) {
        self._identity = nil
        completion(nil)
        self._network = nil
    }

    // MARK: Sync

    let isSyncing = false

    func sync(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion) {
        self._statistics.lastSyncDate = Date()
        queue.async {
            completion(nil, 0, 0)
        }
    }
    
    func syncNotifications(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion) {
        self._statistics.lastSyncDate = Date()
        queue.async {
            completion(nil, 0, 0)
        }
    }

    // MARK: Refresh

    let isRefreshing = false

    func refresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion) {
        self._statistics.lastRefreshDate = Date()
        queue.async {
            completion(nil, 0, false)
        }
    }

    // MARK: Publish

    func publish(post: Post, completion: PublishCompletion) {
        completion("TODO?", FakeBotError.runtimeError("TODO:publish"))
    }

    // MARK: About content

    private func abouts() -> [About] {
        let data = Data.fromJSON(resource: "Abouts.json")
        let contents = try? JSONDecoder().decode([Content].self, from: data)
        let types = contents?.filter { $0.type == .about }
        let abouts = types?.compactMap { $0.about }
        return abouts ?? []
    }

    private func about(for identity: Identity) -> About? {
        let abouts = self.abouts().filter { $0.about == identity }
        return abouts.first
    }

    var about: About? { nil }

    func about(completion: @escaping AboutCompletion) {

        guard let identity = self._identity else {
            completion(nil, FakeBotError.runtimeError("no ID"))
            return
        }

        self.about(identity: identity, completion: completion)
    }

    func about(queue: DispatchQueue, identity: Identity, completion: @escaping AboutCompletion) {
        let about = self.about(for: identity)
        queue.async {
            completion(about, nil)
        }
    }

    func abouts(identities: [Identity], completion:  @escaping AboutsCompletion) {
        completion(self.abouts(), nil)
    }
    
    func abouts(queue: DispatchQueue, completion:  @escaping AboutsCompletion) {
        let abouts = self.abouts()
        queue.async {
            completion(abouts, nil)
        }
    }

    // MARK: Feed content

    func keyAtRecentTop(queue: DispatchQueue, completion: @escaping (MessageIdentifier?) -> Void) {
        queue.async {
            let data = Data.fromJSON(resource: "Feed.json")
            var feed = try? JSONDecoder().decode(KeyValues.self, from: data)
            feed?.sort { $0.value.timestamp < $1.value.timestamp }
            completion(feed?.first?.key)
        }
    }
    
    func recent(completion: PaginatedCompletion) {
        let data = Data.fromJSON(resource: "Feed.json")
        var feed = try? JSONDecoder().decode(KeyValues.self, from: data)
        feed?.sort { $0.value.timestamp < $1.value.timestamp }
        if let feed = feed {
            completion(StaticDataProxy(with: feed), nil)
        } else {
            completion(StaticDataProxy(), nil)
        }
    }

    func everyone(completion: PaginatedCompletion) {
        let data = Data.fromJSON(resource: "Feed.json")
        var feed = try? JSONDecoder().decode(KeyValues.self, from: data)
        feed?.sort { $0.value.timestamp < $1.value.timestamp }
        if let feed = feed {
            completion(StaticDataProxy(with: feed), nil)
        } else {
            completion(StaticDataProxy(), nil)
        }
    }
    
    func keyAtEveryoneTop(queue: DispatchQueue, completion: @escaping (MessageIdentifier?) -> Void) {
        queue.async {
            let data = Data.fromJSON(resource: "Feed.json")
            var feed = try? JSONDecoder().decode(KeyValues.self, from: data)
            feed?.sort { $0.value.timestamp < $1.value.timestamp }
            completion(feed?.first?.key)
        }
    }

    func feed(identity: Identity, completion: PaginatedCompletion) {
        completion(StaticDataProxy(), nil)
    }

    func thread(keyValue: KeyValue, completion: @escaping ThreadCompletion) {
        completion(nil, StaticDataProxy(), nil)
    }
    
    func replies(message: MessageIdentifier, wantPrivate: Bool, completion: @escaping PaginatedCompletion) {
        completion(StaticDataProxy(), FakeBotError.runtimeError("TODO:replies"))
    }

    func mentions(completion: @escaping PaginatedCompletion) {
        completion(StaticDataProxy(), FakeBotError.runtimeError("TODO:mentions"))
    }
    
    // MARK: Statistics

    private var _statistics = BotStatistics()
    var mockStatistics = [BotStatistics]()
    var statistics: BotStatistics { mockStatistics.popLast() ?? _statistics }
    
    func statistics(queue: DispatchQueue, completion: @escaping StatisticsCompletion) {
        let statistics = mockStatistics.popLast() ?? _statistics
        queue.async {
            completion(statistics)
        }
    }
    
    // MARK: Preload
    
    func preloadFeed(at url: URL, completion: @escaping ErrorCompletion) {
        completion(nil)
    }
}
