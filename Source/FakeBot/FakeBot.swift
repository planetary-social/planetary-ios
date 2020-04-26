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
    func knownPubs(completion: @escaping KnownPubsCompletion) {
        fatalError("TODO:knownPubs")
    }
    
    func inviteRedeem(token: String, completion: @escaping ErrorCompletion) {
        fatalError("TODO:invite:redeem")
    }
    
    func thread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) {
        fatalError("TODO:thread:byRootKey")
    }

    func updateReceive(limit: Int, completion: @escaping PublishCompletion) {
           fatalError("TODO:update:rx")
    }
    
    func addBlob(data: Data, completion: @escaping BlobsAddCompletion) {
        fatalError("TODO:blobs:add")
    }

    func addBlob(jpegOf image: UIImage,
                 largestDimension: UInt?,
                 completion: @escaping AddImageCompletion)
    {
        fatalError("TODO:blobs:get")
    }

    func data(for identifier: BlobIdentifier,
              completion: @escaping ((BlobIdentifier, Data?, Error?) -> Void))
    {
        fatalError("TODO")
    }

    func hashtags(completion: @escaping HashtagsCompletion) {
        fatalError("TODO")
    }

    func posts(with hashtag: Hashtag, completion: @escaping FeedCompletion) {
        fatalError("TODO")
    }
    
    // TODO: just lots of stubs
    func uiimage(for identity: Identity, completion: @escaping UIImageCompletion) {
        fatalError("TODO")
    }
    
    func uiimage(for image: Image, completion: @escaping UIImageCompletion) {
        fatalError("TODO")
    }

    func publish(content: ContentCodable, completion: @escaping PublishCompletion) {
        fatalError("TODO")
    }

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion) {
        fatalError("TODO")
    }

    func update(message: MessageIdentifier, content: ContentCodable, completion: @escaping ErrorCompletion) {
        fatalError("TODO")
    }
    
    func follows(identity: Identity, completion: @escaping ContactsCompletion) {
        fatalError("TODO")
    }
    
    func followedBy(identity: Identity, completion: @escaping ContactsCompletion) {
        fatalError("TODO")
    }
    
    func friends(identity: Identity, completion: @escaping ContactsCompletion) {
        fatalError("TODO")
    }
    
    func blocks(identity: Identity, completion: @escaping ContactsCompletion) {
        fatalError("TODO")
    }
    
    func blockedBy(identity: Identity, completion: @escaping ContactsCompletion) {
        fatalError("TODO")
    }

    func block(_ identity: Identity, completion: @escaping PublishCompletion) {
        fatalError("TODO")
    }

    func unblock(_ identity: Identity, completion: @escaping PublishCompletion) {
        fatalError("TODO")
    }

    func follow(_ identity: Identity, completion: @escaping ContactCompletion) {
        fatalError("TODO")
    }

    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion) {
        fatalError("TODO")
    }
    

    private init() {}
    static let shared = FakeBot()

    // MARK: Name

    let name = "FakeBot"
    let version = "1.0"
    
    // MARK: Login
    private var _network: String?
    private var _identity: Identity?
    var identity: Identity? { return self._identity }

    func createSecret(completion: SecretCompletion) {
        completion(nil, FakeBotError.runtimeError("TODO:createSecret"))
    }

    func login(network: NetworkKey,
               hmacKey: HMACKey?,
               secret: Secret,
               completion: ErrorCompletion)
    {
        self._network = network.string
        self._identity = secret.identity
        completion(nil)
    }

    func logout(completion: ErrorCompletion) {
        self._identity = nil
        completion(nil)
        self._network = nil
    }

    // MARK: Sync

    let isSyncing = false

    func sync(queue: DispatchQueue, completion: @escaping SyncCompletion) {
        self._statistics.lastSyncDate = Date()
        queue.async {
            completion(nil, 0, 0)
        }
    }
    
    func syncNotifications(completion: @escaping SyncCompletion) {
        self.sync(queue: .main, completion: completion)
      }

    // MARK: Refresh

    let isRefreshing = false

    func refresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion) {
        self._statistics.lastRefreshDate = Date()
        queue.async {
            completion(nil, 0)
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

    var about: About? { return nil }

    func about(completion: AboutCompletion) {

        guard let identity = self._identity else {
            completion(nil, FakeBotError.runtimeError("no ID"))
            return
        }

        self.about(identity: identity, completion: completion)
    }

    func about(identity: Identity, completion: AboutCompletion) {
        let about = self.about(for: identity)
        completion(about, nil)
    }

    func abouts(identities: Identities, completion:  @escaping AboutsCompletion) {
        completion(self.abouts(), nil)
    }

    // MARK: Feed content

    func recent(completion: RootsCompletion) {
//        let data = Data.fromJSON(resource: "Feed_big.json")
        let data = Data.fromJSON(resource: "Feed.json")
        var feed = try? JSONDecoder().decode(Feed.self, from: data)
        feed?.sort { $0.value.timestamp < $1.value.timestamp }
        completion(feed ?? [], nil)
    }

    func everyone(completion: RootsCompletion) {
    //        let data = Data.fromJSON(resource: "Feed_big.json")
            let data = Data.fromJSON(resource: "Feed.json")
            var feed = try? JSONDecoder().decode(Feed.self, from: data)
            feed?.sort { $0.value.timestamp < $1.value.timestamp }
            completion(feed ?? [], nil)
        }

    func feed(identity: Identity, completion: FeedCompletion) {
        completion([], nil)
    }

    func thread(keyValue: KeyValue, completion: @escaping ThreadCompletion) {
        completion(nil, [], nil)
    }
    
    func replies(message: MessageIdentifier, wantPrivate: Bool, completion: @escaping FeedCompletion) {
        completion([], FakeBotError.runtimeError("TODO:replies"))
    }

    func mentions(completion: @escaping FeedCompletion) {
        completion([], FakeBotError.runtimeError("TODO:mentions"))
    }
    
    // MARK: Statistics

    private var _statistics = MutableBotStatistics()
    var statistics: BotStatistics { return self._statistics }
    
    func statistics(completion: @escaping StatisticsCompletion) {
        completion(_statistics)
    }
}
