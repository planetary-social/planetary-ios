//
//  GoBotAPI.swift
//  FBTT
//
//  Created by Henry Bubert on 13.02.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import Analytics
import CrashReporting

extension String {
    func withGoString<R>(_ call: (gostring_t) -> R) -> R {
        func helper(_ pointer: UnsafePointer<Int8>?, _ call: (gostring_t) -> R) -> R {
            call(gostring_t(p: pointer, n: utf8.count))
        }
        return helper(self, call)
    }
}

private let refreshDelay = DispatchTimeInterval.milliseconds(125)

let greatestRequestedSequenceNumberFromGoBotKey = "greatestRequestedSequenceNumberFromGoBot"

/// This class abstracts the SSB protocol implementation with support for SSB functions like publishing, replicating,
/// fetching posts & threads, etc.
///
/// It has two major components: the GoSSB.xcframework which is a full SSB implementation written in the Go programming
/// language. The `GoBot` communicates with the GoSSB library via FFI. The second component is a SQLite database which
/// is used as a cache to speed up fetching of posts (ADR #4). The GoBot acts as a gatekeeper to these two components,
/// presenting a simpler interface for read and write operations, while internally it manages several threads and
/// synchronization between GoSSB's internal database and the SQLite layer.
class GoBot: Bot {
    
    // TODO https://app.asana.com/0/914798787098068/1122165003408769/f
    // TODO expose in API?
    private let maxBlobBytes = 1024 * 1024 * 8
    
    let name = "GoBot"
    var version: String { self.bot.version }
    
    static let shared = GoBot()
    
    static let versionKey = "GoBotDatabaseVersion"

    private var _identity: Identity?
    var identity: Identity? { self._identity }
    
    var isRestoring = false
    
    var logFileUrls: [URL] {
        let url = URL(fileURLWithPath: self.bot.currentRepoPath.appending("/debug"))
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [URLResourceKey.creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return urls.sorted { (lhs, rhs) -> Bool in
            let lhsCreationDate = try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate
            let rhsCreationDate = try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate
            if let lhsCreationDate = lhsCreationDate, let rhsCreationDate = rhsCreationDate {
                return lhsCreationDate.compare(rhsCreationDate) == .orderedDescending
            } else if lhsCreationDate == nil {
                return false
            } else {
                return true
            }
        }
    }

    /// A queue that will be scheduled at a lower priority than user intiated and UI-type tasks. This queue should be
    /// used for any operations which the user is not explicitly waiting on, i.e. copying posts from go-ssb to the
    /// ViewDatabase.
    private let utilityQueue: DispatchQueue
    
    /// A queue for operations that the user is waiting on like publishing a post, pull-to-refresh, etc.
    private let userInitiatedQueue: DispatchQueue
    
    /// A queue that is used for tasks that aren't safe to execute simultaneously, like publishing and reading
    /// statistics.
    private let serialQueue: DispatchQueue
    
    /// A lock to prevent races when updating the numberOfPublished since it can be updated by `statistics()` and
    /// `publish()`.
    private let numberOfPublishedMessagesLock = NSLock()
 
    private let userDefaults: UserDefaults
    private(set) var config: AppConfiguration?

    private var preloadedPubService: PreloadedPubService?
    private var welcomeService: WelcomeService?
    private var banListAPI = BanListAPI.shared

    // TODO https://app.asana.com/0/914798787098068/1120595810221102/f
    // TODO Make GoBotAPI.database and GoBotAPI.bot private
    let bot: GoBotInternal
    let database = ViewDatabase()

    required init(
        userDefaults: UserDefaults = UserDefaults.standard,
        preloadedPubService: PreloadedPubService? = PreloadedPubServiceAdapter(),
        welcomeService: WelcomeService? = nil
    ) {
        self.userDefaults = userDefaults
        self.preloadedPubService = preloadedPubService
        self.welcomeService = WelcomeServiceAdapter(userDefaults: userDefaults)
        self.utilityQueue = DispatchQueue(
            label: "GoBot-utility",
            qos: .userInitiated,
            attributes: .concurrent,
            autoreleaseFrequency: .workItem,
            target: nil
        )
        self.userInitiatedQueue = DispatchQueue(
            label: "GoBot-userInitiated",
            qos: .userInitiated,
            attributes: .concurrent,
            autoreleaseFrequency: .workItem,
            target: nil
        )
        self.serialQueue = DispatchQueue(
            label: "GoBot-statistics",
            qos: .userInitiated,
            attributes: [],
            autoreleaseFrequency: .workItem,
            target: nil
        )
        self.bot = GoBotInternal(self.userInitiatedQueue)
    }

    // MARK: App Lifecycle

    func suspend() {
        userInitiatedQueue.async {
            self.bot.disconnectAll()
        }
    }

    func exit() async {
        _ = await Task(priority: .userInitiated) {
            self.bot.disconnectAll()
            self.database.close()
        }.result
    }
    
    func dropDatabase(for configuration: AppConfiguration) async throws {
        Log.info("Dropping GoBot database...")
                
        do {
            try await logout()
        } catch {
            guard case BotError.notLoggedIn = error else {
                throw error
            }
        }
        
        do {
            let databaseDirectory = try configuration.databaseDirectory()
            try FileManager.default.removeItem(atPath: databaseDirectory)
        } catch {
            let nsError = error as NSError
            // It's ok if the directory is already gone
            guard nsError.domain == NSCocoaErrorDomain,
                nsError.code == 4,
                let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError,
                underlyingError.domain == NSPOSIXErrorDomain,
                underlyingError.code == 2 else {
                    throw error
            }
        }
        
        Analytics.shared.trackDidDropDatabase()
    }

    // MARK: Login/Logout
    
    func createSecret(completion: SecretCompletion) {
        Thread.assertIsMainThread()
        
        guard let generatedKey = ssbGenKey() else {
            completion(nil, GoBotError.unexpectedFault("createSecret failed"))
            return
        }
        let secret = Secret(from: String(cString: generatedKey))
        free(generatedKey)
        completion(secret, nil)
    }
    
    func login(queue: DispatchQueue, config: AppConfiguration, completion: @escaping ErrorCompletion) {
        guard let network = config.network else {
            queue.async { completion(BotError.invalidAppConfiguration) }
            return
        }

        let secret = config.secret
        guard self._identity == nil else {
            if secret.identity == self._identity {
                queue.async { completion(nil) }
            } else {
                queue.async { completion(BotError.alreadyLoggedIn) }
            }
            return
        }
        
        self.config = config
        let hmacKey = config.hmacKey
        
        var repoPrefix: String

        do {
            if database.isOpen() {
                database.close()
            }
            
            repoPrefix = try config.databaseDirectory()
            
            try self.database.open(
                path: repoPrefix,
                user: secret.identity
            )
        } catch {
            queue.async { completion(error) }
            return
        }

        // spawn go-bot in the background to return early
        userInitiatedQueue.async {
            // used for locating the files in the simulator
            Log.shared.info("===> starting gobot with prefix: \(repoPrefix)")
            let loginErr = self.bot.login(
                network: network,
                hmacKey: hmacKey,
                secret: secret,
                pathPrefix: repoPrefix
            )
            
            defer {
                queue.async { completion(loginErr) }
            }
            
            guard loginErr == nil else {
                return
            }
            
            // Save GoBot version to disk in case we need to migrate in the future.
            // This is a side-effect that may cause problems if we want to use other bots in the future.
            self.userDefaults.set(self.version, forKey: GoBot.versionKey)
            self.userDefaults.synchronize()
            
            self._identity = secret.identity
            
            do {
                try self.welcomeService?.insertNewMessages(in: self.database)
            } catch {
                Log.error("Failed to run welcome service: \(error.localizedDescription)")
                CrashReporting.shared.reportIfNeeded(error: error)
            }
            self.preloadedPubService?.preloadPubs(in: self, from: nil)
            
            Task.detached(priority: .background) {
                await self.fetchAndApplyBanList(for: secret.identity)
            }
            
            Log.shared.info("Finished login")
        }
    }
    
    func logout(completion: @escaping ErrorCompletion) {
        Thread.assertIsMainThread()
        if self._identity == nil {
            completion(BotError.notLoggedIn)
            return
        }
        if !self.bot.logout() {
            Log.unexpected(.botError, "failed to logout")
        }
        database.close()
        self._identity = nil
        self.config = nil
        completion(nil)
    }

    // MARK: Sync
    
    func seedPubAddresses(
        addresses: [PubAddress],
        queue: DispatchQueue,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        utilityQueue.async {
            do {
                try addresses.forEach { address throws in
                    try self.database.saveAddress(
                        feed: address.key,
                        address: address.multiserver,
                        redeemed: nil
                    )
                }
                queue.async {
                    completion(.success(()))
                }
            } catch {
                queue.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    func knownPubs(completion: @escaping KnownPubsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let knownPubs = try self.database.getAllKnownPubs()
                DispatchQueue.main.async { completion(knownPubs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }
    
    func joinedPubs(queue: DispatchQueue, completion: @escaping (([Pub], Error?) -> Void)) {
        userInitiatedQueue.async {
            do {
                let pubs = try self.database.getJoinedPubs()
                queue.async {
                    completion(pubs, nil)
                }
            } catch {
                queue.async {
                    completion([], error)
                }
            }
        }
    }
    
    func joinedRooms() async throws -> [Room] {
        let task = Task.detached(priority: .userInitiated) {
            return try self.database.getJoinedRooms()
        }
        return try await task.value
    }
    
    func insert(room: Room) async throws {
        let task = Task.detached(priority: .userInitiated) {
            return try self.database.insert(room: room)
        }
        return try await task.value
    }
    
    func delete(room: Room) async throws {
        let task = Task.detached(priority: .userInitiated) {
            return try self.database.delete(room: room)
        }
        return try await task.value
    }
    
    func registeredAliases() async throws -> [RoomAlias] {
        let task = Task.detached(priority: .userInitiated) {
            return try self.database.getRegisteredAliases()
        }
        return try await task.value
    }
    
    func register(alias: String, in room: Room) async throws -> RoomAlias {
        let task = Task.detached(priority: .userInitiated) { () throws -> RoomAlias in
            if self.bot.register(alias: alias, in: room) {
                return try self.database.insertRoomAlias(url: URL(string: "https://" + alias + "." + room.address.host)!, room: room)
            } else {
                // TODO: localize, better error messages i.e. in case of conflicts.
                throw GoBotError.unexpectedFault("Failed to register room alias")
            }
        }
        return try await task.value
    }
    
    func revoke(alias: RoomAlias) async throws {
        
    }
    

    private var _isSyncing = false
    var isSyncing: Bool { self._isSyncing }

    /// Instructs the bot to attempt to connect to the given peers and gossip with them.
    ///
    /// - Parameters:
    ///   - queue: The queue that `completion` to be called on.
    ///   - peers: The peers to attempt to connect to. This function does not guarantee that all peers will be tried.
    ///   - completion: A block that will be called when the operation completes.
    ///
    /// TODO https://app.asana.com/0/914798787098068/1121148308653004/f
    /// TODO make sync not return immediately because it's querying peers
    /// note that dialSomePeers() is called, then the completion is called
    /// some time later, this is a workaround until we can figure out how
    /// to determine peer connection status and progress
    func sync(queue: DispatchQueue, peers: [MultiserverAddress], completion: @escaping SyncCompletion) {
        guard self.bot.isRunning else {
            queue.async {
                completion(GoBotError.unexpectedFault("bot not started"), 0, 0)
            }
            return
        }
        guard self._isSyncing == false else {
            queue.async {
                completion(nil, 0, 0)
            }
            return
        }

        self._isSyncing = true
        let elapsed = Date()

        utilityQueue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialSomePeers(from: peers)
            let after = self.repoNumberOfMessages()
            let newMessages = after - before
            queue.async {
                self.notifySyncComplete(
                    in: -elapsed.timeIntervalSinceNow,
                    numberOfMessages: newMessages,
                    completion: completion
                )
            }
        }
    }
    
    func connect(to address: MultiserverAddress) {
        guard self.bot.isRunning else {
            return
        }
        
        utilityQueue.async {
            _ = self.bot.dialOne(peer: address)
        }
    }
    
    /// Instructs the bot to attempt to connect to one of the given peers and gossip with them.
    /// Note: this looks like it does the same thing as `sync(queue:peers:completion:)` but it only attempts to dial one
    /// peer. Presumably this is intended to be a quicker sync operation.
    ///
    /// - Parameters:
    ///   - queue: The queue that `completion` will be called on.
    ///   - peers: A list of peers to connect to. One will be chosen randomly.
    ///   - completion: A block that will be called when the operation has finished.
    func syncNotifications(queue: DispatchQueue, peers: [MultiserverAddress], completion: @escaping SyncCompletion) {
        guard self.bot.isRunning else {
            queue.async {
                completion(GoBotError.unexpectedFault("bot not started"), 0, 0)
            }
            return
        }
        guard self._isSyncing == false else {
            queue.async {
                completion(nil, 0, 0)
            }
            return
        }

        self._isSyncing = true
        let elapsed = Date()

        utilityQueue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialForNotifications(from: peers)
            let after = self.repoNumberOfMessages()
            let newMessages = after - before
            queue.async {
                self.notifySyncComplete(
                    in: -elapsed.timeIntervalSinceNow,
                    numberOfMessages: newMessages,
                    completion: completion
                )
            }
        }
    }

    private func repoNumberOfMessages() -> Int {
        guard let counts = try? self.bot.repoStatus() else { return -1 }
        return Int(counts.messages)
    }

    private func notifySyncComplete(
        in elapsed: TimeInterval,
        numberOfMessages: Int,
        completion: @escaping SyncCompletion
    ) {
        self._isSyncing = false
        serialQueue.async {
            self._statistics.lastSyncDate = Date()
            self._statistics.lastSyncDuration = elapsed
        }
        completion(nil, elapsed, numberOfMessages)
        NotificationCenter.default.post(name: .didSync, object: nil)
    }
    
    // refresh specific feed - when we view a profile we should ask gobot to refresh that feed. It might not get back in time
    // to update what the user sees but it'll help. In particular this will happen with pubs.
    
    func replicate(feed: FeedIdentifier) {
        userInitiatedQueue.async {
            self.bot.replicate(feed: feed)
        }
    }
    

    // MARK: Refresh

    private var _isRefreshing = false
    var isRefreshing: Bool { self._isRefreshing }
    
    /// Copies some new data from the go-ssb log into `ViewDatabase`.
    ///
    /// - Parameters:
    ///   - load: The amount of data to fetch.
    ///   - queue: The queue that `completion` will be called on.
    ///   - completion: A block that will be called when the operation has completed.
    func refresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion) {
        self.internalRefresh(load: load, queue: queue, completion: completion)
    }

    private func internalRefresh(load: RefreshLoad, queue: DispatchQueue, completion: @escaping RefreshCompletion) {
        guard self._isRefreshing == false else {
            queue.async {
                completion(.success(false), 0)
            }
            return
        }
        
        self._isRefreshing = true
        
        let elapsed = Date()
        self.utilityQueue.async {
            self.updateReceive(limit: load.rawValue) { [weak self] result in
                queue.async {
                    self?.notifyRefreshComplete(
                        in: -elapsed.timeIntervalSinceNow,
                        result: result,
                        completion: completion
                    )
                }
            }
        }
    }

    private func notifyRefreshComplete(
        in elapsed: TimeInterval,
        result: Result<Bool, Error>,
        completion: @escaping RefreshCompletion
    ) {
        self._isRefreshing = false
        serialQueue.async {
            self._statistics.lastRefreshDate = Date()
            self._statistics.lastRefreshDuration = elapsed
        }
        completion(result, elapsed)
        NotificationCenter.default.post(name: .didRefresh, object: nil)
    }
    
    // MARK: Invites
    
    func redeemInvitation(to star: Star, completionQueue: DispatchQueue, completion: @escaping ErrorCompletion) {
        self.utilityQueue.async {
                        
            // Verify that we can connect to the pub, because go-ssb locks up while redeeming an invitation.
            // https://github.com/planetary-social/planetary-ios/issues/272
            star.testConnection { connectionSuccessful in
                guard connectionSuccessful else {
                    completion(GoBotError.unexpectedFault("Could not connect to Star."))
                    return
                }
                
                star.invite.withGoString { goStr in
                    if ssbInviteAccept(goStr) {
                        do {
                            let feed = star.feed
                            let address = star.address
                            let redeemed = Date().timeIntervalSince1970 * 1000
                            try self.database.saveAddress(feed: feed, address: address.multiserver, redeemed: redeemed)
                            Analytics.shared.trackDidJoinPub(at: star.address.multiserver.string)
                        } catch {
                            CrashReporting.shared.reportIfNeeded(error: error)
                        }
                        completionQueue.async {
                            completion(nil)
                        }
                    } else {
                        completionQueue.async {
                            completion(GoBotError.unexpectedFault("invite did not work. Maybe try again?"))
                        }
                    }
                }
            }
        }
    }
    
    // MARK: Publish
    private var lastPublishFireTime = DispatchTime.now()
    
    /// Publishes the given content on the logged-in user's feed.
    /// - Parameters:
    ///   - content: The content to be published
    ///   - completionQueue: The queue that `completion` should be called on.
    ///   - completion: A block that will be called with the result of the operation when it is finished.
    func publish(content: ContentCodable, completionQueue: DispatchQueue, completion: @escaping PublishCompletion) {
        userInitiatedQueue.async {
            guard let identity = self._identity else {
                completionQueue.async {
                    completion(MessageIdentifier.null, BotError.notLoggedIn)
                }
                return
            }
            
            // Forked feed protection
            do {
                self.numberOfPublishedMessagesLock.lock()
                let preventForks = self.userDefaults.object(forKey: "prevent_feed_from_forks") as? Bool
                if preventForks == true || preventForks == nil {
                    guard try self.publishingWouldFork(feed: identity) == false else {
                        self.numberOfPublishedMessagesLock.unlock()
                        completionQueue.async {
                            completion(MessageIdentifier.null, BotError.forkProtection)
                        }
                        return
                    }
                }
            } catch {
                self.numberOfPublishedMessagesLock.unlock()
                completion(MessageIdentifier.null, error)
            }
            
            self.bot.publish(content) { [weak self] key, error in
                if let error = error {
                    self?.numberOfPublishedMessagesLock.unlock()
                    completionQueue.async { completion(MessageIdentifier.null, error) }
                    return
                }
                
                Log.info("Published message with key \(key)")
                
                // Copy the newly published post into the ViewDatabase immediately.
                do {
                    guard let self = self else {
                        completionQueue.async { completion(MessageIdentifier.null, BotError.notLoggedIn) }
                        return
                    }
                    let lastPostIndex = try self.database.largestSeqFromPublishedLog()
                    let publishedPosts = try self.bot.getPublishedLog(after: lastPostIndex)
                    try self.database.fillMessages(msgs: publishedPosts)
                    try self.updateNumberOfPublishedMessages(for: identity)
                    self.numberOfPublishedMessagesLock.unlock()
                    completionQueue.async { completion(key, nil) }
                } catch {
                    self?.numberOfPublishedMessagesLock.unlock()
                    completionQueue.async { completion(MessageIdentifier.null, error) }
                }
            }
        }
    }
    
    func publishingWouldFork(feed: FeedIdentifier) throws -> Bool {
        let numberOfMessagesInRepo = try self.database.numberOfMessages(for: feed)
        let knownNumberOfMessagesInKeychain = self.config?.numberOfPublishedMessages ?? 0
        return numberOfMessagesInRepo < knownNumberOfMessagesInKeychain
    }
                                                                 
    /// Updates the number of known published messages for the given feed.
    private func updateNumberOfPublishedMessages(for feed: FeedIdentifier) throws {
        guard let configuration = config else {
            return
        }
        
        let numberOfMessagesInRepo = try self.database.numberOfMessages(for: feed)
        configuration.numberOfPublishedMessages = max(
            numberOfMessagesInRepo,
            configuration.numberOfPublishedMessages
        )
        configuration.apply()
    }

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion) {
        var targetMessage: Message?
        do {
            targetMessage = try self.database.post(with: message)
        } catch {
            completion(GoBotError.duringProcessing("failed to get message", error))
            return
        }

        guard let targetMessage = targetMessage else {
            let error = ViewDatabaseError.unknownMessage(message)
            let encapsulatedError = GoBotError.duringProcessing("delete: failed to get() from viewDB", error)
            completion(encapsulatedError)
            return
        }
        
        if targetMessage.author != self._identity {
            // drop from view regardless of format
            do {
                try self.database.delete(message: message)
            } catch {
                completion(GoBotError.duringProcessing("failed to excute delete action", error))
                return
            }
        }

        guard targetMessage.author.algorithm == .ggfeed else {
            completion(GoBotError.unexpectedFault("unsupported feed format for deletion"))
            return
        }
        
        guard targetMessage.contentType == .post else {
            // we _could_ delete .about but we can't select them anyway... (we could display them on user profiles?)
            completion(ViewDatabaseError.unexpectedContentType("can only delete posts"))
            return
        }
        
        guard targetMessage.author == self._identity else {
            // drop content directly / can't request others to do so
            do {
                try self.bot.nullContent(
                    author: targetMessage.author,
                    sequence: UInt(targetMessage.sequence)
                )
            } catch {
                completion(GoBotError.duringProcessing("failed to null content", error))
                return
            }
            completion(nil)
            return
        }
        
        // publish signed drop-content-request for other peers
        let dropContentRequest = DropContentRequest(
            sequence: UInt(targetMessage.sequence),
            hash: message
        )

        self.publish(content: dropContentRequest) { _, error in
            // fillMessages will make it go away from the view
            completion(error)
        }
    }

    func update(message: MessageIdentifier, content: ContentCodable, completion: @escaping ErrorCompletion) {
        print("TODO: Implement post update in Bot.")
    }

    /// Computes how many messages are in go-ssb's log but not `ViewDatabase`.
    /// - Returns: A tuple containing the index of the last received message in the go-ssb log and the number of
    ///     messages that the ViewDatabase is missing.
    func needsViewFill() throws -> (Int64, Int) {
        var lastRxSeq: Int64 = 0
        do {
            let lastRxSeqFromDB = try self.database.largestSeqNotFromPublishedLog()
            var lastRxSeqFromDisk: Int64 = -1
            if let userDefaultsValue = userDefaults.object(
                forKey: greatestRequestedSequenceNumberFromGoBotKey
            ) as? Int64 {
                lastRxSeqFromDisk = userDefaultsValue
            }
            lastRxSeq = max(lastRxSeqFromDB, lastRxSeqFromDisk)
        } catch {
            throw GoBotError.duringProcessing("view query failed", error)
        }
        
        do {
            let repoStats = try self.bot.repoStatus()
            if repoStats.messages == 0 {
                return (lastRxSeq, 0)
            }
            let diff = Int(Int64(repoStats.messages) - 1 - lastRxSeq)
            if diff < 0 {
                let errorMessage = "needsViewFill: more msgs in view then in GoBot repo: \(lastRxSeq) (diff: \(diff))"
                let error = GoBotError.unexpectedFault(errorMessage)
                CrashReporting.shared.reportIfNeeded(error: error)
                throw error
            }
            
            return (lastRxSeq, diff)
        } catch {
            throw GoBotError.duringProcessing("bot current failed", error)
        }
    }
    
    private func repairViewConstraints21012020(with author: Identity, current: Int64) -> (Analytics.BotRepair, Error?) {
        // fields we want to include in the tracked event
        var repair = Analytics.BotRepair(
            function: "ViewConstraints21012020",
            numberOfMessagesInDB: current,
            numberOfMessagesInRepo: self._statistics.repo.messageCount
        )

        let (worked, maybeReport) = self.bot.fsckAndRepair()
        guard worked else {
            return (repair, GoBotError.unexpectedFault("[constraint violation] failed to heal gobot repository"))
        }

        guard let report = maybeReport else { // there was nothing to repair?
            return (repair, GoBotError.unexpectedFault("[constraint violation] viewdb error but nothing to repair"))
        }

        repair.reportedAuthors = report.Authors.count
        repair.reportedMessages = report.Messages

        if !report.Authors.contains(author) {
            Log.unexpected(.botError, "ViewConstraints21012020 warning: affected author not in heal report")
            // there could be others, so go on
        }

        for author in report.Authors {
            do {
                try self.database.delete(allFrom: author)
            } catch ViewDatabaseError.unknownAuthor {
                // after the viewdb schema bump, ppl that have this bug
                // only have it in the gobot after the update
                // therefore we can skip this if the viewdb is filling for the first time
                guard current == -1 else {
                    let errorMessage = "[constraint violation] expected author from fsck report in viewdb"
                    return (repair, GoBotError.unexpectedFault(errorMessage))
                }
                continue
            } catch {
                let errorMessage = "[constraint violation] unable to drop affected feed from viewdb"
                return (repair, GoBotError.duringProcessing(errorMessage, error))
            }
        }

        return (repair, nil)
    }
    
    // should only be called by refresh() (which does the proper completion on mainthread)
    private func updateReceive(limit: Int32 = 15_000, completion: @escaping (Result<Bool, Error>) -> Void) {
        var current: Int64 = 0
        var diff: Int = 0

        do {
            (current, diff) = try self.needsViewFill()
        } catch {
            completion(.failure(error))
            return
        }
        
        guard diff > 0 else {
            // still might want to update privates
            #if DEBUG
            Log.debug("[rx log] viewdb already up to date.")
            #endif
            self.updatePrivate(completion: completion)
            return
        }
        
        // TOOD: redo until diff==0
        do {
            Log.debug("[rx log] asking go-ssb for new messages.")
            
            // If the go log is empty we need to request 0. Otherwise request the next seq number.
            let startSeq = UInt64(current <= 0 ? 0 : current + 1)
            let msgs = try self.bot.getReceiveLog(startSeq: startSeq, limit: limit)
            
            guard !msgs.isEmpty else {
                print("warning: triggered update but got no messages from receive log")
                // If the bot's log from startSeq to startSeq+limit is full of nulled messages then no messages will
                // be returned. In this case we need to artificially bump up our sequence number so we don't get
                // stuck requesting the same messages again and again.
                userDefaults.set(startSeq + UInt64(limit), forKey: greatestRequestedSequenceNumberFromGoBotKey)
                userDefaults.synchronize()
                completion(.success(true))
                return
            }
            
            do {
                try self.database.fillMessages(msgs: msgs)
        
                if let lastReceivedSeq = msgs.last?.receivedSeq {
                    userDefaults.set(lastReceivedSeq, forKey: greatestRequestedSequenceNumberFromGoBotKey)
                    userDefaults.synchronize()
                }

                Analytics.shared.trackBotDidUpdateDatabase(
                    count: msgs.count,
                    firstTimestamp: msgs[0].receivedTimestamp,
                    lastTimestamp: msgs[msgs.count - 1].receivedTimestamp,
                    lastHash: msgs[msgs.count - 1].key
                )
                if diff < limit { // view is up2date now
                    completion(.success(true))
                    // disable private messages until there is UI for it AND ADD SQLCYPHER!!!111
                    // self.updatePrivate(completion: completion)
                } else {
                    #if DEBUG
                    print("#rx log# \(diff - Int(limit)) messages left in go-ssb offset log")
                    #endif
                    completion(.success(false))
                }
            } catch ViewDatabaseError.messageConstraintViolation(let author, let sqlErr) {
                let (repair, error) = self.repairViewConstraints21012020(with: author, current: current)
    
                Analytics.shared.trackBotDidRepair(
                    databaseError: sqlErr,
                    error: error?.localizedDescription,
                    repair: repair
                )

                #if DEBUG
                print("[rx log] viewdb fill of aborted and repaired.")
                #endif
                completion(.failure(error ?? GoBotError.unexpectedFault("updateReceive failed")))
            } catch {
                let encapsulatedError = GoBotError.duringProcessing(
                    "viewDB: message filling failed: \(error.localizedDescription)",
                    error
                )
                Log.optional(encapsulatedError)
                CrashReporting.shared.reportIfNeeded(error: encapsulatedError)
                completion(.failure(encapsulatedError))
            }
        } catch {
            completion(.failure(error))
        }
    }
    
    private func updatePrivate(completion: @escaping (Result<Bool, Error>) -> Void) {
        var count: Int64 = 0
        do {
            let rawCount = try self.database.stats(table: .privates)
            count = Int64(rawCount)
            
            // TOOD: redo until diff==0
            let msgs = try self.bot.getPrivateLog(startSeq: count, limit: 1000)
            
            if !msgs.isEmpty {
                try self.database.fillMessages(msgs: msgs, pms: true)
                
                print("[private log] private log filled with \(msgs.count) msgs (started at \(count))")
            }
            
            completion(.success(false))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: blobs

    func addBlob(data: Data, completion: @escaping BlobsAddCompletion) {
        Thread.assertIsMainThread()
        guard data.count <= self.maxBlobBytes else {
            DispatchQueue.main.async {
                completion(BlobIdentifier.null, BotError.blobMaximumSizeExceeded)
            }
            return
        }
        userInitiatedQueue.async {
            self.bot.blobsAdd(data: data) { identifier, error in
                DispatchQueue.main.async {
                    completion(identifier, error)
                }
            }
        }
    }

    // TODO consider that having UIImage at this level requires UIKit
    // which might be inappropriate at this level
    @available(*, deprecated)
    func addBlob(jpegOf image: UIImage, largestDimension: UInt? = nil, completion: @escaping AddImageCompletion) {
        Thread.assertIsMainThread()

        // convenience closure to keep code cleaner
        let completionOnMain: AddImageCompletion = { image, error in
            DispatchQueue.main.async { completion(image, error) }
        }

        userInitiatedQueue.async {

            // encode image or return failures
            var image: UIImage? = image
            if let dimension = largestDimension { image = image?.resized(toLargestDimension: CGFloat(dimension)) }
            guard let uiimage = image else { completionOnMain(nil, BotError.blobUnsupportedFormat); return }
            guard let data = uiimage.jpegData(compressionQuality: 0.5) else {
                completionOnMain(nil, BotError.blobUnsupportedFormat)
                return
            }
            guard data.count <= self.maxBlobBytes else {
                completionOnMain(nil, BotError.blobMaximumSizeExceeded)
                return
            }

            // add to log and return Image if successful
            self.bot.blobsAdd(data: data) { identifier, error in
                CrashReporting.shared.reportIfNeeded(error: error)
                if Log.optional(error) { completionOnMain(nil, error); return }
                let image = ImageMetadata(link: identifier, jpegImage: uiimage, data: data)
                completionOnMain(image, nil)
            }
        }
    }

    func data(for identifier: BlobIdentifier, completion: @escaping ((BlobIdentifier, Data?, Error?) -> Void)) {
        guard identifier.isValidIdentifier else {
            completion(identifier, nil, BotError.blobInvalidIdentifier)
            return
        }
        
        guard !isRestoring else {
            completion(identifier, nil, BotError.restoring)
            return
        }

        userInitiatedQueue.async {

            // get non-empty data from blob storage
            do {
                let data = try self.bot.blobGet(ref: identifier)
                DispatchQueue.main.async {
                    if data.isEmpty {
                        completion(identifier, nil, BotError.blobUnavailable)
                    } else {
                        completion(identifier, data, nil)
                    }
                }
            }

            // noop, just trigger a sync if not already active
            catch {
                DispatchQueue.main.async {
                    completion(identifier, nil, error)
                }
            }
        }
    }
    
    func store(url: URL, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion) {
        // Use a same thread here, no need to mess with the our standard queue.
        do {
            let repoURL = try self.bot.blobFileURL(ref: identifier)
            try FileManager.default.createDirectory(
                at: repoURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: nil
            )
            try FileManager.default.copyItem(at: url, to: repoURL)
            completion(repoURL, nil)
        } catch {
            completion(nil, error)
        }
    }
    
    func store(data: Data, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion) {
        let url: URL
        do {
            url = try self.bot.blobFileURL(ref: identifier)
        } catch {
            completion(nil, error)
            return
        }

        userInitiatedQueue.async {
            do {
                try FileManager.default.createDirectory(
                    at: url.deletingLastPathComponent(),
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                try data.write(to: url, options: .atomic)
                completion(url, nil)
            } catch {
                completion(nil, error)
            }
        }
    }

    // MARK: About

    /// IMPORTANT
    /// This cached value is for convenience only, and should reflect
    /// how caching might work for other content.  Since the bot knows
    /// about the logged in identity it follows that it could know be
    /// About as well.  However, unless publishing an About also updates
    /// this value, this is an incomplete implementation.
    /// DO NOT DO THIS FOR OTHER CONTENT!
    private var _about: About?
    var about: About? {
        
        if self._about == nil, let identity = self.identity {
            self._about = try? self.database.getAbout(for: identity)
        }
        return self._about
    }

    func about(completion: @escaping AboutCompletion) {
        guard let user = self._identity else {
            completion(nil, BotError.notLoggedIn)
            return
        }
        self.about(identity: user, completion: completion)
    }
    
    func about(queue: DispatchQueue, identity: Identity, completion: @escaping AboutCompletion) {
        userInitiatedQueue.async {
            do {
                var about = try self.database.getAbout(for: identity)
                if about == nil {
                    about = About(about: identity)
                }
                
                queue.async {
                    if about?.identity == self._identity { self._about = about }
                    completion(about, nil)
                }
            } catch {
                queue.async { completion(nil, error) }
            }
        }
    }

    func abouts(identities: [Identity], completion: @escaping AboutsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            var abouts: [About] = []
            for identity in identities {
                if let about = try? self.database.getAbout(for: identity) {
                    abouts += [about]
                }
            }
            DispatchQueue.main.async { completion(abouts, nil) }
        }
    }
                
    func abouts(queue: DispatchQueue, completion: @escaping AboutsCompletion) {
        userInitiatedQueue.async {
            do {
                let abouts = try self.database.getAbouts()
                queue.async {
                    completion(abouts, nil)
                }
            } catch {
                queue.async {
                    completion([], error)
                }
            }
        }
    }
    
    func abouts(matching filter: String) async throws -> [About] {
        let dbTask = Task.detached(priority: .high) {
            try self.database.abouts(withNameLike: filter)
        }
        
        return try await dbTask.value
    }

    // MARK: Contacts

    func follow(_ identity: Identity, completion: @escaping ContactCompletion) {
        identity.assertNotMe()
        let contact = Contact(contact: identity, following: true)
        self.publish(content: contact) { _, error in
            let contactOrNilIfError = (error == nil ? contact : nil)
            completion(contactOrNilIfError, error)
        }
    }

    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion) {
        identity.assertNotMe()
        let contact = Contact(contact: identity, following: false)
        self.publish(content: contact) { _, error in
            let contactOrNilIfError = (error == nil ? contact : nil)
            completion(contactOrNilIfError, error)
        }
    }

    func follows(identity: Identity, completion: @escaping ContactsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let follows: [Identity] = try self.database.getFollows(feed: identity)
                DispatchQueue.main.async { completion(follows, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }
    
    func followedBy(identity: Identity, completion: @escaping ContactsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let follows: [Identity] = try self.database.followedBy(feed: identity)
                DispatchQueue.main.async { completion(follows, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    func followings(identity: FeedIdentifier, queue: DispatchQueue, completion: @escaping AboutsCompletion) {
        userInitiatedQueue.async {
            do {
                let follows: [About] = try self.database.getFollows(feed: identity)
                queue.async {
                    completion(follows, nil)
                }
            } catch {
                queue.async {
                    completion([], error)
                }
            }
        }
    }

    func followers(identity: FeedIdentifier, queue: DispatchQueue, completion: @escaping AboutsCompletion) {
        userInitiatedQueue.async {
            do {
                let follows: [About] = try self.database.followedBy(feed: identity)
                queue.async {
                    completion(follows, nil)
                }
            } catch {
                queue.async {
                    completion([], error)
                }
            }
        }
    }
    
    func friends(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let identities = try self.database.getBidirectionalFollows(feed: identity)
                DispatchQueue.main.async {
                    completion(identities, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }

    func socialStats(for identity: Identity, completion: @escaping ((SocialStats, Error?) -> Void)) {
        userInitiatedQueue.async { [database] in
            do {
                let count = try database.countNumberOfFollowersAndFollows(feed: identity)
                DispatchQueue.main.async {
                    completion(count, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion(SocialStats(numberOfFollowers: 0, numberOfFollows: 0), error)
                }
            }
        }
    }
    
    // MARK: Blocks & Bans
    
    func blocks(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        userInitiatedQueue.async {
            do {
                let identities = try self.database.getBlocks(feed: identity)
                DispatchQueue.main.async {
                    completion(identities, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }
    
    func blockedBy(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        userInitiatedQueue.async {
            do {
                let identities = try self.database.blockedBy(feed: identity)
                DispatchQueue.main.async {
                    completion(identities, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }

    func block(_ identity: Identity, completion: @escaping PublishCompletion) {
        let block = Contact(contact: identity, blocking: true)
        self.publish(content: block) { messageIdentifier, error in
            guard error == nil else {
                completion("", error)
                return
            }

            do {
                try self.database.delete(allFrom: identity)
            } catch {
                completion("", GoBotError.duringProcessing("deleting feed from view failed", error))
                return
            }

            do {
                try self.bot.nullFeed(author: identity)
            } catch {
                completion("", GoBotError.duringProcessing("deleting feed from bot failed", error))
                return
            }

            completion(messageIdentifier, nil)
            NotificationCenter.default.post(name: .didBlockUser, object: identity)
        }
    }

    func unblock(_ identity: Identity, completion: @escaping PublishCompletion) {
        self.publish(content: Contact(contact: identity, blocking: false)) { messageIdentifier, error in
            guard error == nil else {
                completion("", error)
                return
            }
            completion(messageIdentifier, nil)
        }
    }
    
    /// Downloads the latest ban list from the Planetary API and applies it to the db.
    private func fetchAndApplyBanList(for identity: FeedIdentifier) async {
        var banList: BanList = []
        do {
            banList = try await self.banListAPI.retreiveBanList(for: identity)
        } catch {
            Log.unexpected(.botError, "failed to get ban list: \(String(describing: error))")
            return
        }
            
        do {
            let (bannedAuthors, unbannedAuthors) = try self.database.applyBanList(banList)
            
            // add as blocked peers to bot (those dont have contact messages)
            for author in bannedAuthors {
                try bot.nullFeed(author: author)
                bot.ban(feed: author)
            }
            
            for author in unbannedAuthors {
                bot.unban(feed: author)
            }
        } catch {
            Log.unexpected(.botError, "failed to apply ban list: \(error)")
        }
    }

    // MARK: Feeds
    
    /// The algorithm we use to filter and sort the home feed.
    var homeFeedStrategy: FeedStrategy {
        if let data = userDefaults.object(forKey: UserDefaults.homeFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        
        return RecentlyActivePostsAndContactsAlgorithm()
    }

    /// The algorithm we use to filter and sort the discover tab feed.
    var discoverFeedStrategy: FeedStrategy {
        if let data = userDefaults.object(forKey: UserDefaults.discoveryFeedStrategy) as? Data,
            let decodedObject = try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data),
            let strategy = decodedObject as? FeedStrategy {
            return strategy
        }
        
        return RandomAlgorithm(onlyFollowed: false)
    }
    
    // old recent
    func recent(completion: @escaping PaginatedCompletion) {
        userInitiatedQueue.async {
            do {
                let strategyString = String(describing: type(of: self.homeFeedStrategy))
                Log.debug("GoBot fetching recent posts with strategy: \(strategyString)")
                let proxy = try self.database.paginatedFeed(with: self.homeFeedStrategy)
                DispatchQueue.main.async { completion(proxy, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }
    
    func numberOfRecentItems(since message: MessageIdentifier, completion: @escaping CountCompletion) {
        userInitiatedQueue.async {
            do {
                let count = try self.database.numberOfRecentPosts(with: self.homeFeedStrategy, since: message)
                DispatchQueue.main.async {
                    completion(.success(count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    // posts from everyone, not just who you follow
    func everyone(completion: @escaping PaginatedCompletion) {
        userInitiatedQueue.async {
            do {
                let msgs = try self.database.paginatedFeed(with: self.discoverFeedStrategy)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    func thread(message: Message, completion: @escaping ThreadCompletion) {
        assert(message.content.isPost)
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            if let rootKey = message.content.post?.root {
                do {
                    let root = try self.database.post(with: rootKey)
                    let replies = try self.database.getRepliesTo(thread: root.key)
                    DispatchQueue.main.async {
                        completion(root, StaticDataProxy(with: replies), nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, StaticDataProxy(), error)
                    }
                }
            } else {
                self.internalThread(rootKey: message.key, completion: completion)
            }
        }
    }

    func thread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            self.internalThread(rootKey: rootKey, completion: completion)
        }
    }

    private func internalThread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) {
        do {
            let root = try self.database.post(with: rootKey)
            let replies = try self.database.getRepliesTo(thread: rootKey)
            DispatchQueue.main.async {
                completion(root, StaticDataProxy(with: replies), nil)
            }
        } catch {
            DispatchQueue.main.async {
                completion(nil, StaticDataProxy(), error)
            }
        }
    }

    func mentions(completion: @escaping PaginatedCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let messages = try self.database.mentions(limit: 1000)
                let proxy = StaticDataProxy(with: messages)
                DispatchQueue.main.async { completion(proxy, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    func markMessageAsRead(_ message: MessageIdentifier) {
        userInitiatedQueue.async {
            do {
                let wasAlreadRead = try self.database.isMessageForReportRead(for: message)
                try self.database.markMessageAsRead(identifier: message, isRead: true)
                let shouldPostReadReportNotification = wasAlreadRead == false
                if shouldPostReadReportNotification {
                    NotificationCenter.default.post(
                        name: .didUpdateReportReadStatus,
                        object: nil,
                        userInfo: nil
                    )
                }
            } catch {
                Log.optional(error)
            }
        }
    }

    func markAllMessageAsRead(queue: DispatchQueue, completion: @escaping VoidCompletion) {
        userInitiatedQueue.async {
            do {
                self.database.needsToSetAllMessagesAsRead = true
                try self.database.setAllMessagesAsReadIfNeeded()
                queue.async {
                    completion(.success(()))
                }
            } catch {
                queue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func numberOfUnreadReports(queue: DispatchQueue, completion: @escaping CountCompletion) {
        userInitiatedQueue.async {
            do {
                let count = try self.database.countNumberOfUnreadReports()
                queue.async {
                    completion(.success(count))
                }
            } catch {
                queue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func reports(queue: DispatchQueue, completion: @escaping (([Report], Error?) -> Void)) {
        userInitiatedQueue.async {
            do {
                let reports = try self.database.reports()
                queue.async {
                    completion(reports, nil)
                }
            } catch {
                queue.async {
                    completion([], error)
                }
            }
        }
    }

    func numberOfReports(since report: Report, completion: @escaping CountCompletion) {
        userInitiatedQueue.async {
            do {
                let count = try self.database.countNumberOfReports(since: report)
                DispatchQueue.main.async {
                    completion(.success(count))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    func feed(strategy: FeedStrategy, completion: @escaping PaginatedCompletion) {
        userInitiatedQueue.async {
            do {
                let strategyString = String(describing: type(of: strategy))
                Log.debug("GoBot fetching posts with strategy: \(strategyString)")
                let proxy = try self.database.paginatedFeed(with: strategy)
                DispatchQueue.main.async { completion(proxy, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    func feed(identity: Identity, completion: @escaping PaginatedCompletion) {
        feed(strategy: NoHopFeedAlgorithm(identity: identity), completion: completion)
    }
    
    func post(from key: MessageIdentifier) throws -> Message {
        try self.database.post(with: key)
    }

    // MARK: Hashtags

    /// The algorithm we use to sort the list of hashtags
    var hashtagListStrategy: HashtagListStrategy {
        PopularHashtagsAlgorithm()
    }

    func hashtags(completion: @escaping HashtagsCompletion) {
        userInitiatedQueue.async { [hashtagListStrategy] in
            do {
                let hashtags = try self.database.hashtags(with: hashtagListStrategy)
                DispatchQueue.main.async { completion(hashtags, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    func hashtags(usedBy identity: Identity, limit: Int, completion: @escaping HashtagsCompletion) {
        userInitiatedQueue.async { [database] in
            do {
                let hashtags = try database.hashtags(identity: identity, limit: limit)
                DispatchQueue.main.async { completion(hashtags, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    func posts(with hashtag: Hashtag, completion: @escaping PaginatedCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let messages = try self.database.messagesForHashtag(name: hashtag.name)
                let proxy = StaticDataProxy(with: messages)
                DispatchQueue.main.async { completion(proxy, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }
    
    func posts(matching filter: String) async throws -> [Message] {
        let task = Task.detached(priority: .high) {
            return try self.database.posts(matching: filter)
        }
        
        return try await task.result.get()
    }

    // MARK: Statistics

    /// Any access to this variable should be done on `statisticsQueue`.
    private var _statistics = BotStatistics()

    func statistics(queue: DispatchQueue, completion: @escaping StatisticsCompletion) {
        serialQueue.async {
            let counts = try? self.bot.repoStatus()
            let sequence = try? self.database.stats(table: .messagekeys)

            var ownMessages = -1
            self.numberOfPublishedMessagesLock.lock()
            if let identity = self._identity, let ownMessageCount = try? self.database.numberOfMessages(for: identity) {
                ownMessages = ownMessageCount
                self.saveNumberOfPublishedMessages(from: self._statistics.repo)
            }
            self.numberOfPublishedMessagesLock.unlock()
            
            var feedCount: Int = -1
            if let rawFeedCount = counts?.feeds {
                feedCount = Int(rawFeedCount)
            }
            var messageCount: Int = -1
            if let rawMessageCount = counts?.messages {
                messageCount = Int(rawMessageCount)
            }
            self._statistics.repo = RepoStatistics(
                path: self.bot.currentRepoPath,
                feedCount: feedCount,
                messageCount: messageCount,
                numberOfPublishedMessages: ownMessages,
                lastHash: counts?.lastHash ?? ""
            )

            let connectionCount = self.bot.openConnections()
            let openConnections = self.bot.openConnectionList()
            
            self._statistics.peer = PeerStatistics(
                count: openConnections.count,
                connectionCount: connectionCount,
                identities: openConnections,
                open: openConnections
            )
            
            let (recentlyDownloadedPostCount, recentlyDownloadedPostDuration) = self.recentlyDownloadedPostData()
            self._statistics.recentlyDownloadedPostCount = recentlyDownloadedPostCount
            self._statistics.recentlyDownloadedPostDuration = recentlyDownloadedPostDuration
            
            let sqliteMessageCount = (try? self.database.messageCount()) ?? 0
            self._statistics.db = DatabaseStatistics(
                lastReceivedMessage: sequence ?? -3,
                messageCount: sqliteMessageCount
            )
            
            let statistics = self._statistics
            queue.async {
                completion(statistics)
            }
            Analytics.shared.trackStatistics(statistics.analyticsStatistics)
        }
    }
    
    func numberOfNewMessages(since: Date) throws -> Int {
        try self.database.receivedMessageCount(since: since)
    }
    
    func recentlyDownloadedPostData() -> (recentlyDownloadedPostCount: Int, recentlyDownloadedPostDuration: Int) {
        let recentlyDownloadedPostDuration = 15 // minutes
        var recentlyDownloadedPostCount = 0
        do {
            let startDate = Date(timeIntervalSinceNow: Double(recentlyDownloadedPostDuration) * -60)
            recentlyDownloadedPostCount = try self.database.receivedMessageCount(since: startDate)
        } catch {
            Log.optional(error)
        }
        return (recentlyDownloadedPostCount, recentlyDownloadedPostDuration)
    }
    
    /// Saves the number of published messages to the AppConfiguration. Used for forked feed protection.
    private func saveNumberOfPublishedMessages(from statistics: RepoStatistics) {
        let currentNumberOfPublishedMessages = statistics.numberOfPublishedMessages
        if let configuration = config,
            currentNumberOfPublishedMessages > -1,
            configuration.numberOfPublishedMessages < currentNumberOfPublishedMessages {
            configuration.numberOfPublishedMessages = currentNumberOfPublishedMessages
            configuration.apply()
        }
    }
    
    func lastReceivedTimestam() throws -> Double {
        Double(try self.database.lastReceivedTimestamp())
    }
    
    /// Verifies that the bot is still responding to function calls. #727
    func isBotStuck() async throws -> Bool {
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = Task.detached(priority: .high) {
            _ = try self.bot.repoStatus()
            semaphore.signal()
        }
        
        if semaphore.wait(timeout: .now() + .seconds(15)) == .timedOut {
            return true
        }
        
        if case .failure(let error) = await task.result {
            throw error
        }
        
        return false
    }
    
    // MARK: Preloading
    
    func preloadFeed(at url: URL, completion: @escaping ErrorCompletion) {
        userInitiatedQueue.async {
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                do {
                    let msgs = try JSONDecoder().decode([Message].self, from: data)

                    var lastRxSeq: Int64 = try self.database.minimumReceivedSeq()
                    
                    let newMesgs = msgs.map { (message: Message) -> Message in
                        lastRxSeq -= 1
                        return Message(
                            key: message.key,
                            value: MessageValue(
                                author: message.author,
                                content: message.content,
                                hash: message.hash,
                                previous: message.previous,
                                sequence: message.sequence,
                                signature: message.signature,
                                claimedTimestamp: message.receivedTimestamp
                            ),
                            timestamp: message.receivedTimestamp,
                            receivedSeq: lastRxSeq,
                            hashedKey: message.key.sha256hash
                        )
                    }

                    try self.database.fillMessages(msgs: newMesgs)
                    
                    completion(nil)
                } catch {
                    print(error) // shows error
                    print("Decoding failed")// local message
                    completion(error)
                }
            } catch {
                print(error) // shows error
                print("Unable to read file")// local message
                completion(error)
            }
        }
    }

    // MARK: Raw messages

    func raw(of message: Message, completion: @escaping RawCompletion) {
        userInitiatedQueue.async {
            let identity = message.author
            let sequence = message.sequence
            guard sequence >= UInt64.min, sequence <= UInt64.max else {
                completion(.failure(AppError.unexpected))
                return
            }
            identity.withGoString { feedRef in
                guard let pointer = ssbGetRawMessage(feedRef, UInt64(sequence)) else {
                    completion(.failure(GoBotError.unexpectedFault("failed to get raw message")))
                    return
                }
                let string = String(cString: pointer)
                free(pointer)
                completion(.success(string))
            }
        }
    }
}
