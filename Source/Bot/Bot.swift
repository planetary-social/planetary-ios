//
//  Created by Christoph on 1/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// Convenience types to simplify writing completion closures.
typealias AboutCompletion = ((About?, Error?) -> Void)
typealias AboutsCompletion = (([About], Error?) -> Void)
typealias AddImageCompletion = ((Image?, Error?) -> Void)
typealias BlobsAddCompletion = ((BlobIdentifier, Error?) -> Void)
typealias BlobsStoreCompletion = ((URL?, Error?) -> Void)
typealias ContactCompletion = ((Contact?, Error?) -> Void)
typealias ContactsCompletion = (([Identity], Error?) -> Void)
typealias ErrorCompletion = ((Error?) -> Void)
typealias KeyValuesCompletion = ((KeyValues, Error?) -> Void)
typealias PaginatedCompletion = ((PaginatedKeyValueDataProxy, Error?) -> Void)
typealias HashtagCompletion = ((Hashtag?, Error?) -> Void)
typealias HashtagsCompletion = (([Hashtag], Error?) -> Void)
typealias PublishCompletion = ((MessageIdentifier, Error?) -> Void)
typealias RefreshCompletion = ((Error?, TimeInterval) -> Void)
typealias SecretCompletion = ((Secret?, Error?) -> Void)
typealias SyncCompletion = ((Error?, TimeInterval, Int) -> Void)
typealias ThreadCompletion = ((KeyValue?, PaginatedKeyValueDataProxy, Error?) -> Void)
typealias UIImageCompletion = ((Identifier?, UIImage?, Error?) -> Void)
typealias KnownPubsCompletion = (([KnownPub], Error?) -> Void)
typealias StatisticsCompletion = ((BotStatistics) -> Void)

enum RefreshLoad: Int, CaseIterable {
    case tiny = 500
    case short = 15000
    case medium = 45000
    case long = 100000
}

// Abstract interface to any SSB bot implementation.
protocol Bot {

    // MARK: Name
    var name: String { get }
    var version: String { get }

    // MARK: AppLifecycle
    func suspend()
    func exit()
    
    // MARK: Logs
    var logFileUrls: [URL] { get }
    
    // MARK: Identity

    var identity: Identity? { get }

    // TODO https://app.asana.com/0/914798787098068/1109609875273529/f
    func createSecret(completion: SecretCompletion)

    // MARK: Sync
    
    func knownPubs(completion: @escaping KnownPubsCompletion)
    
    func pubs(queue: DispatchQueue, completion: @escaping (([Pub], Error?) -> Void))

    // Sync is the bot reaching out to remote peers and gathering the latest
    // data from the network.  This only updates the local log and requires
    // calling `refresh` to ensure the view database is updated.
    var isSyncing: Bool { get }
    func sync(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion)

    // TODO: this is temporary until live-streaming is deployed on the pubs
    func syncNotifications(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion)

    // MARK: Refresh

    // Refresh is the filling of the view database from the bot's index.  Note
    // that `sync` and `refresh` can be called at different intervals, it's just
    // that `refresh` should be called before `recent` if the newest data is desired.
    var isRefreshing: Bool { get }
    func refresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion)

    // MARK: Login

    func login(queue: DispatchQueue, network: NetworkKey, hmacKey: HMACKey?, secret: Secret, completion: @escaping ErrorCompletion)
    func logout(completion: @escaping ErrorCompletion)

    // MARK: Invites

    // Redeem uses the invite information and accepts it.
    // It adds the pub behind the address to the connection sheduling table and follows it.
    func inviteRedeem(queue: DispatchQueue, token: String, completion: @escaping ErrorCompletion)

    // MARK: Publish

    // TODO https://app.asana.com/0/914798787098068/1114777817192216/f
    // TOOD for some lower level applications it might make sense to add Secret to publish
    // so that you can publish as multiple IDs (think groups or invites)
    // The `content` argument label is required to avoid conflicts when specialized
    // forms of `publish` are created.  For example, `publish(post)` will publish a
    // `Post` model, but then also the embedded `Hashtag` models.
    func publish(queue: DispatchQueue, content: ContentCodable, completion: @escaping PublishCompletion)

    // MARK: Post Management

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion)
    func update(message: MessageIdentifier, content: ContentCodable, completion: @escaping ErrorCompletion)

    // MARK: About

    var about: About? { get }
    func about(completion: @escaping AboutCompletion)
    func about(queue: DispatchQueue, identity: Identity, completion:  @escaping AboutCompletion)
    func abouts(identities: [Identity], completion:  @escaping AboutsCompletion)
    func abouts(queue: DispatchQueue, completion:  @escaping AboutsCompletion)

    // MARK: Contact

    func follow(_ identity: Identity, completion: @escaping ContactCompletion)
    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion)

    func follows(identity: Identity, completion:  @escaping ContactsCompletion)
    func followedBy(identity: Identity, completion:  @escaping ContactsCompletion)
    
    func followers(identity: Identity, queue: DispatchQueue, completion: @escaping AboutsCompletion)
    func followings(identity: Identity, queue: DispatchQueue, completion: @escaping AboutsCompletion)
    
    func friends(identity: Identity, completion:  @escaping ContactsCompletion)

    // TODO the func names should be swapped
    func blocks(identity: Identity, completion:  @escaping ContactsCompletion)
    func blockedBy(identity: Identity, completion:  @escaping ContactsCompletion)

    // MARK: Block

    func block(_ identity: Identity, completion: @escaping PublishCompletion)
    func unblock(_ identity: Identity, completion: @escaping PublishCompletion)

    // MARK: Hashtags

    func hashtags(completion: @escaping HashtagsCompletion)
    func posts(with hashtag: Hashtag, completion: @escaping PaginatedCompletion)
    
    // MARK: Feed
    
    // everyone's posts
    func everyone(completion: @escaping PaginatedCompletion)

    func recent(completion: @escaping PaginatedCompletion)
    
    /// Returns all the messages created by the specified Identity.
    /// This is useful for showing all the posts from a particular
    /// person, like in an About screen.
    func feed(identity: Identity, completion: @escaping PaginatedCompletion)
    
    /// Returns the thread of messages related to the specified message.  The root
    /// of the thread will be returned if it is not the specified message.
    func thread(keyValue: KeyValue, completion: @escaping ThreadCompletion)
    func thread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion)

    /// Returns all the messages in a feed that mention the active identity.
    func mentions(completion: @escaping PaginatedCompletion)

    /// Reports (unifies mentions, replies, follows) for the active identity.
    func reports(queue: DispatchQueue, completion: @escaping (([Report], Error?) -> Void))

    // MARK: Blob publishing

    func addBlob(data: Data, completion: @escaping BlobsAddCompletion)

    // TODO https://app.asana.com/0/914798787098068/1122165003408766/f
    // TODO consider if this is appropriate to know about UIImage at this level
    @available(*, deprecated)
    func addBlob(jpegOf image: UIImage,
                 largestDimension: UInt?,
                 completion: @escaping AddImageCompletion)

    // MARK: Blob loading

    func data(for identifier: BlobIdentifier,
              completion: @escaping ((BlobIdentifier, Data?, Error?) -> Void))
    
    /// Saves a file to disk in the same path it would be if fetched through the net.
    /// Useful for storing a blob fetched from an external source.
    func store(url: URL, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion)
    func store(data: Data, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion)

    // MARK: Statistics

    func statistics(queue: DispatchQueue, completion: @escaping StatisticsCompletion)
    
    func lastReceivedTimestam() throws -> Double
    
    @available(*, deprecated)
    var statistics: BotStatistics { get }
    
    // MARK: Preloading
    
    func preloadFeed(at url: URL, completion: @escaping ErrorCompletion)
    
}

extension Bot {
    
    func login(network: NetworkKey, hmacKey: HMACKey?, secret: Secret, completion: @escaping ErrorCompletion) {
        self.login(queue: .main,
                   network: network,
                   hmacKey: hmacKey,
                   secret: secret,
                   completion: completion)
    }
    func sync(peers: [Peer], completion: @escaping SyncCompletion) {
        self.sync(queue: .main, peers: peers, completion: completion)
    }
    
    func abouts(completion:  @escaping AboutsCompletion) {
        self.abouts(queue: .main, completion: completion)
    }

    func followers(identity: Identity, completion:  @escaping AboutsCompletion) {
        self.followers(identity: identity, queue: .main, completion: completion)
    }

    func followings(identity: Identity, completion:  @escaping AboutsCompletion) {
        self.followings(identity: identity, queue: .main, completion: completion)
    }

    func statistics(completion: @escaping StatisticsCompletion) {
        self.statistics(queue: .main, completion: completion)
    }
    
    func reports(completion: @escaping (([Report], Error?) -> Void)) {
        self.reports(queue: .main, completion: completion)
    }
    
    func about(identity: Identity, completion:  @escaping AboutCompletion) {
        self.about(queue: .main, identity: identity, completion: completion)
    }
    
    func inviteRedeem(token: String, completion: @escaping ErrorCompletion) {
        self.inviteRedeem(queue: .main, token: token, completion: completion)
    }
    
    func pubs(completion: @escaping (([Pub], Error?) -> Void)) {
        self.pubs(queue: .main, completion: completion)
    }
    
    func publish(content: ContentCodable, completion: @escaping PublishCompletion) {
        self.publish(queue: .main, content: content, completion: completion)
    }
}
