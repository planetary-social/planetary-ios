//
//  Created by Christoph on 1/17/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit

// Convenience types to simplify writing completion closures.
typealias AboutCompletion = ((About?, Error?) -> Void)
typealias AboutsCompletion = (([About], Error?) -> Void)
typealias AddImageCompletion = ((ImageMetadata?, Error?) -> Void)
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
typealias CountCompletion = ((Int, Error?) -> Void)

/// - Error: an error if the refresh failed
/// - TimeInterval: the amount of time the refresh took
/// - Bool: True if the view database is fully up to date with the backing store.
typealias RefreshCompletion = ((Error?, TimeInterval, Bool) -> Void)
typealias SecretCompletion = ((Secret?, Error?) -> Void)
typealias SyncCompletion = ((Error?, TimeInterval, Int) -> Void)
typealias ThreadCompletion = ((KeyValue?, PaginatedKeyValueDataProxy, Error?) -> Void)
typealias UIImageCompletion = ((Identifier?, UIImage?, Error?) -> Void)
typealias KnownPubsCompletion = (([KnownPub], Error?) -> Void)
typealias StatisticsCompletion = ((BotStatistics) -> Void)

enum RefreshLoad: Int32, CaseIterable {
    case tiny = 500 // about 1 second on modern hardware
    case short = 5_000 
    case medium = 45_000 // about 30 seconds
    case long = 100_000 // about 60 seconds
}

/// Abstract interface to any SSB bot implementation.
/// - SeeAlso: `GoBot`
protocol Bot: AnyObject {

    // MARK: Name
    var name: String { get }
    var version: String { get }

    // MARK: AppLifecycle
    init(userDefaults: UserDefaults, preloadedPubService: PreloadedPubService?)
    func suspend()
    func exit() async
    func dropDatabase(for configuration: AppConfiguration) async throws
    
    /// A flag that signals that the bot is resyncing the user's feed from the network.
    /// Currently used to suppress push notifications because the user has already seen them.
    var isRestoring: Bool { get set }
    
    // MARK: Logs
    var logFileUrls: [URL] { get }
    
    // MARK: Identity

    var identity: Identity? { get }

    // TODO https://app.asana.com/0/914798787098068/1109609875273529/f
    func createSecret(completion: SecretCompletion)

    // MARK: Sync
    
    /// Ensure that these list of addresses are taken into consideration when establishing connections
    func seedPubAddresses(addresses: [PubAddress],
                          queue: DispatchQueue,
                          completion: @escaping (Result<Void, Error>) -> Void)
    
    func knownPubs(completion: @escaping KnownPubsCompletion)
    
    /// Retrieves a list of all pubs the current user is currently a member of.
    func joinedPubs(queue: DispatchQueue, completion: @escaping (([Pub], Error?) -> Void))

    var isSyncing: Bool { get }
    
    /// Sync is the bot reaching out to remote peers and gathering the latest gossip from the network. This only
    /// updates the local log and requires calling `refresh` to ensure the view database is updated.
    /// - Parameters:
    ///   - queue: the queue that `completion` will be called on.
    ///   - peers: a list of peers to gossip with. Only a subset of this list will be used.
    ///   - completion: a handler called with the result of the operation.
    func sync(queue: DispatchQueue, peers: [MultiserverAddress], completion: @escaping SyncCompletion)

    // TODO: this is temporary until live-streaming is deployed on the pubs
    func syncNotifications(queue: DispatchQueue, peers: [MultiserverAddress], completion: @escaping SyncCompletion)

    // MARK: Refresh

    // Refresh is the filling of the view database from the bot's index.  Note
    // that `sync` and `refresh` can be called at different intervals, it's just
    // that `refresh` should be called before `recent` if the newest data is desired.
    var isRefreshing: Bool { get }
    func refresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion)

    // MARK: Login

    /// Initializes the bot with the given `config`. This instructs the `Bot` to assume the identity of the user
    /// whose data is contained in `AppConfiguration`.
    /// - Parameter queue: The queue that `completion` will be called on.
    /// - Parameter config: An object containing high-level parameters like the user's keys and the network key.
    /// - Parameter completion: A handler that will be called with the result of the operation.
    func login(queue: DispatchQueue, config: AppConfiguration, completion: @escaping ErrorCompletion)
    func logout(completion: @escaping ErrorCompletion)

    // MARK: Invites

    // Redeem uses the invite information and accepts it.
    // It adds the pub behind the address to the connection sheduling table and follows it.
    func redeemInvitation(to: Star, completionQueue: DispatchQueue, completion: @escaping ErrorCompletion)

    // MARK: Publish

    // TODO https://app.asana.com/0/914798787098068/1114777817192216/f
    // TOOD for some lower level applications it might make sense to add Secret to publish
    // so that you can publish as multiple IDs (think groups or invites)
    // The `content` argument label is required to avoid conflicts when specialized
    // forms of `publish` are created.  For example, `publish(post)` will publish a
    // `Post` model, but then also the embedded `Hashtag` models.
    func publish(content: ContentCodable, completionQueue: DispatchQueue, completion: @escaping PublishCompletion)

    /// Computes whether publishing a new message at this time would fork the user's feed. Forks occur when publishing
    /// a message before the user's feed has resynced from the network during a restore.
    func publishingWouldFork(feed: FeedIdentifier) throws -> Bool
        
    // MARK: Post Management

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion)
    func update(message: MessageIdentifier, content: ContentCodable, completion: @escaping ErrorCompletion)

    // MARK: About

    @available(*, deprecated)
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

    /// Fetch the social stats of an identity
    ///
    /// - parameter identity: The identity to make the query
    /// - parameter completion: The completion block to handle the results
    func socialStats(for identity: Identity, completion: @escaping ((SocialStats, Error?) -> Void))

    // TODO the func names should be swapped
    func blocks(identity: Identity, completion:  @escaping ContactsCompletion)
    func blockedBy(identity: Identity, completion:  @escaping ContactsCompletion)

    // MARK: Block

    func block(_ identity: Identity, completion: @escaping PublishCompletion)
    func unblock(_ identity: Identity, completion: @escaping PublishCompletion)

    // MARK: Hashtags

    func hashtags(completion: @escaping HashtagsCompletion)

    /// Fetch the hashtags that someone has published to recently
    ///
    /// - parameter identity: The publisher's identity
    /// - parameter limit: The maximum number of hashtags to look for
    /// - parameter completion: The completion block to handle the results
    func hashtags(usedBy identity: Identity, limit: Int, completion: @escaping HashtagsCompletion)

    func posts(with hashtag: Hashtag, completion: @escaping PaginatedCompletion)
    
    // MARK: Feed
    
    // everyone's posts
    func everyone(completion: @escaping PaginatedCompletion)
    
    // your feed
    func recent(completion: @escaping PaginatedCompletion)
    func numberOfRecentItems(since message: MessageIdentifier, completion: @escaping CountCompletion)
    
    /// Returns all the messages created by the specified Identity.
    /// This is useful for showing all the posts from a particular
    /// person, like in an About screen.
    func feed(identity: Identity, completion: @escaping PaginatedCompletion)
    
    /// Fetches the post with the given ID from the database.
    func post(from key: MessageIdentifier) throws -> KeyValue
    
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
    
    func recentlyDownloadedPostData() -> (recentlyDownloadedPostCount: Int, recentlyDownloadedPostDuration: Int)
    
    func lastReceivedTimestam() throws -> Double
    
    // MARK: Preloading
    
    func preloadFeed(at url: URL, completion: @escaping ErrorCompletion)
}

extension Bot {
    
    @MainActor func createSecret() async throws -> Secret {
        try await withCheckedThrowingContinuation { continuation in
            self.createSecret { secret, error in
                if let secret = secret {
                    continuation.resume(with: .success(secret))
                } else if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: BotError.internalError)
                }
            }
        }
    }
    
    func login(config: AppConfiguration, completion: @escaping ErrorCompletion) {
        self.login(queue: .main, config: config, completion: completion)
    }
    
    func login(config: AppConfiguration) async throws {
        let error: Error? = await withCheckedContinuation { continuation in
            self.login(config: config) { error in
                continuation.resume(with: .success(error))
            }
        }
        if let error = error {
            throw error
        }
    }
    
    @MainActor func logout() async throws {
        let error: Error? = await withCheckedContinuation { continuation in
            self.logout { error in
                continuation.resume(with: .success(error))
            }
        }
        if let error = error {
            throw error
        }
    }
    
    func sync(peers: [MultiserverAddress], completion: @escaping SyncCompletion) {
        self.sync(queue: .main, peers: peers, completion: completion)
    }
    
    @discardableResult
    func refresh(
        load: RefreshLoad,
        queue: DispatchQueue = .main
    ) async throws -> (TimeInterval, Bool) {
        try await withCheckedThrowingContinuation { continuation in
            refresh(load: load, queue: queue) { error, result2, result3 in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (result2, result3))
                }
            }
        }
    }

    func recent() async throws -> PaginatedKeyValueDataProxy {
        try await withCheckedThrowingContinuation { continuation in
            recent { proxy, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: proxy)
                }
            }
        }
    }

    func numberOfRecentItems(since message: MessageIdentifier) async throws -> Int {
        try await withCheckedThrowingContinuation { continuation in
            numberOfRecentItems(since: message) { count, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: count)
                }
            }
        }
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
    
    func statistics() async -> BotStatistics {
        await withCheckedContinuation { continuation in
            statistics { result in
                continuation.resume(returning: result)
            }
        }
    }
    
    func reports(completion: @escaping (([Report], Error?) -> Void)) {
        self.reports(queue: .main, completion: completion)
    }
    
    func about(identity: Identity, completion:  @escaping AboutCompletion) {
        self.about(queue: .main, identity: identity, completion: completion)
    }
    
    func about(identity: Identity) async throws -> About? {
        try await withCheckedThrowingContinuation { continuation in
            about(identity: identity) { about, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: about)
            }
        }
    }
    
    func about() async throws -> About? {
        try await withCheckedThrowingContinuation { continuation in
            about { about, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: about)
            }
        }
    }

    /// Fetch the hashtags that someone has published to recently
    ///
    /// - parameter identity: The publisher's identity
    /// - parameter limit: The maximum number of hashtags to look for
    /// - returns: Array with the hashtags found
    ///
    /// This function will throw if it cannot access the database
    func hashtags(usedBy identity: Identity, limit: Int) async throws -> [Hashtag] {
        try await withCheckedThrowingContinuation { continuation in
            hashtags(usedBy: identity, limit: limit) { hashtags, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: hashtags)
            }
        }
    }

    /// Fetch the social stats of an identity
    ///
    /// - parameter identity: The identity to make the query
    /// - returns: A FollowStats object with the number of followers and follows
    ///
    /// This function will throw if it cannot access the database
    func socialStats(for identity: Identity) async throws -> SocialStats {
        try await withCheckedThrowingContinuation { continuation in
            socialStats(for: identity) { socialStats, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: socialStats)
            }
        }
    }
    
    func redeemInvitation(to star: Star, completion: @escaping ErrorCompletion) {
        self.redeemInvitation(to: star, completionQueue: .main, completion: completion)
    }
    
    func joinedPubs(completion: @escaping (([Pub], Error?) -> Void)) {
        self.joinedPubs(queue: .main, completion: completion)
    }
    
    func joinedPubs() async throws -> [Pub] {
        try await withCheckedThrowingContinuation { continuation in
            joinedPubs(queue: DispatchQueue.main) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    func publish(content: ContentCodable, completion: @escaping PublishCompletion) {
        self.publish(content: content, completionQueue: .main, completion: completion)
    }
    
    func publish(content: ContentCodable) async throws -> MessageIdentifier {
        try await withCheckedThrowingContinuation { continuation in
            publish(content: content) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }
    
    func seedPubAddresses(addresses: [PubAddress], completion: @escaping (Result<Void, Error>) -> Void) {
        self.seedPubAddresses(addresses: addresses, queue: .main, completion: completion)
    }
}
