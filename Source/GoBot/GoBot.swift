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

extension String {
    func withGoString<R>(_ call: (gostring_t) -> R) -> R {
        func helper(_ pointer: UnsafePointer<Int8>?, _ call: (gostring_t) -> R) -> R {
            return call(gostring_t(p: pointer, n: utf8.count))
        }
        return helper(self, call)
    }
}


fileprivate let refreshDelay = DispatchTimeInterval.milliseconds(125)

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
    var version: String { return self.bot.version }
    
    static let shared = GoBot()

    private var _identity: Identity? = nil
    var identity: Identity? { return self._identity }
    
    var logFileUrls: [URL] {
        let url = URL(fileURLWithPath: self.bot.currentRepoPath.appending("/debug"))
        guard let urls = try? FileManager.default.contentsOfDirectory(at: url,
                                                                      includingPropertiesForKeys: [URLResourceKey.creationDateKey],
                                                                      options: .skipsHiddenFiles) else {
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

    // TODO https://app.asana.com/0/914798787098068/1120595810221102/f
    // TODO Make GoBotAPI.database and GoBotAPI.bot private
    let bot: GoBotInternal
    let database = ViewDatabase()

    init() {
        self.utilityQueue = DispatchQueue(label: "GoBot-utility",
                                          qos: .utility,
                                          attributes: .concurrent,
                                          autoreleaseFrequency: .workItem,
                                          target: nil)
        self.userInitiatedQueue = DispatchQueue(label: "GoBot-userInitiated",
                                                qos: .userInitiated,
                                                attributes: .concurrent,
                                                autoreleaseFrequency: .workItem,
                                                target: nil)
        self.bot = GoBotInternal(self.userInitiatedQueue)
    }

    // MARK: App Lifecycle

    func suspend() {
        userInitiatedQueue.async {
            self.bot.disconnectAll()
        }
    }

    func exit() {
        userInitiatedQueue.async {
            self.bot.disconnectAll()
        }
    }

    // MARK: Login/Logout
    
    func createSecret(completion: SecretCompletion) {
        Thread.assertIsMainThread()
        
        guard let kp = ssbGenKey() else {
            completion(nil, GoBotError.unexpectedFault("createSecret failed"))
            return
        }
        let sec = Secret(from: String(cString: kp))
        free(kp)
        completion(sec, nil)
    }
    
    func login(queue: DispatchQueue, network: NetworkKey, hmacKey: HMACKey?, secret: Secret, completion: @escaping ErrorCompletion) {

        guard self._identity == nil else {
            if secret.identity == self._identity {
                queue.async { completion(nil) }
            } else {
                queue.async { completion(BotError.alreadyLoggedIn) }
            }
            return
        }

        // lookup Application Support folder for bot and database
        let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory,
                                                                 .userDomainMask, true)
        guard appSupportDirs.count > 0 else {
            queue.async { completion(GoBotError.unexpectedFault("no support dir")) }
            return
        }

        let repoPrefix = appSupportDirs[0]
            .appending("/FBTT")
            .appending("/"+network.hexEncodedString())
        
        if !self.database.isOpen() {
            do {
                try self.database.open(path: repoPrefix, user: secret.identity)
            } catch {
                queue.async { completion(error) }
                return
            }
        } else {
            Log.unexpected(.botError, "\(#function) warning: database still open")
        }
   
        // spawn go-bot in the background to return early
        userInitiatedQueue.async {
            #if DEBUG
            // used for locating the files in the simulator
            print("===> starting gobot with prefix: \(repoPrefix)")
            #endif
            let loginErr = self.bot.login(network: network,
                                          hmacKey: hmacKey,
                                          secret: secret,
                                          pathPrefix: repoPrefix)
            
            defer {
                queue.async { completion(loginErr) }
            }
            
            guard loginErr == nil else {
                return
            }
            
            self._identity = secret.identity
            
            BlockedAPI.shared.retreiveBlockedList() {
                blocks, err in
                guard err == nil else {
                    Log.unexpected(.botError, "failed to get blocks: \(err)");
                    return
                } // Analitcis error instead?

                var authors: [FeedIdentifier] = []
                do {
                    authors = try self.database.updateBlockedContent(blocks)
                } catch {
                    // Analitcis error instead?
                    Log.unexpected(.botError, "viewdb failed to update blocked content: \(error)")
                }

                // add as blocked peers to bot (those dont have contact messages)
                do {
                    for a in authors {
                        try self.bot.nullFeed(author: a)
                        self.bot.block(feed: a)
                    }
                } catch {
                    // Analitcis error instead?
                    Log.unexpected(.botError, "failed to drop and block content: \(error)")
                }
            }
        }
    }
    
    func logout(completion: @escaping ErrorCompletion) {
        Thread.assertIsMainThread()
        if self._identity == nil {
            DispatchQueue.main.async { completion(BotError.notLoggedIn) }
            return
        }
        if !self.bot.logout() {
            Log.unexpected(.botError, "failed to logout")
        }
        database.close()
        self._identity = nil
        DispatchQueue.main.async { completion(nil) }
    }

    // MARK: Sync
    
    func seedPubAddresses(addresses: [PubAddress], queue: DispatchQueue, completion: @escaping (Result<Void, Error>) -> Void) {
        utilityQueue.async {
            do {
                try addresses.forEach { address throws in
                    try self.database.saveAddress(feed: address.key,
                                                  address: address.multipeer,
                                                  redeemed: nil)
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
            var err: Error? = nil
            var kps: [KnownPub] = []
            defer {
                   DispatchQueue.main.async { completion(kps, err) }
            }
            
            do {
                kps = try self.database.getAllKnownPubs()
            } catch {
                err = error
            }
         }
     }
    
    func pubs(queue: DispatchQueue, completion: @escaping (([Pub], Error?) -> Void)) {
        userInitiatedQueue.async {
            do {
                let pubs = try self.database.getRedeemedPubs()
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

    private var _isSyncing = false
    var isSyncing: Bool { return self._isSyncing }


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
    func sync(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion) {
        guard self.bot.isRunning else {
            queue.async {
                completion(GoBotError.unexpectedFault("bot not started"), 0, 0);
            }
            return
        }
        guard self._isSyncing == false else {
            queue.async {
                completion(nil, 0, 0);
            }
            return
        }

        self._isSyncing = true
        let elapsed = Date()

        utilityQueue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialSomePeers(from: peers)
            let after = self.repoNumberOfMessages()
            let new = after - before
            queue.async {
                self.notifySyncComplete(in: -elapsed.timeIntervalSinceNow,
                                        numberOfMessages: new,
                                        completion: completion)
            }
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
    func syncNotifications(queue: DispatchQueue, peers: [Peer], completion: @escaping SyncCompletion) {
        guard self.bot.isRunning else {
            queue.async {
                completion(GoBotError.unexpectedFault("bot not started"), 0, 0);
            }
            return
        }
        guard self._isSyncing == false else {
            queue.async {
                completion(nil, 0, 0);
            }
            return
        }

        self._isSyncing = true
        let elapsed = Date()

        utilityQueue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialForNotifications(from: peers)
            let after = self.repoNumberOfMessages()
            let new = after - before
            queue.async {
                self.notifySyncComplete(in: -elapsed.timeIntervalSinceNow,
                                        numberOfMessages: new,
                                        completion: completion)
            }
        }
    }

    private func repoNumberOfMessages() -> Int {
        guard let counts = try? self.bot.repoStatus() else { return -1 }
        return Int(counts.messages)
        
    }

    private func notifySyncComplete(in elapsed: TimeInterval,
                                    numberOfMessages: Int,
                                    completion: @escaping SyncCompletion)
    {
        self._isSyncing = false
        self._statistics.lastSyncDate = Date()
        self._statistics.lastSyncDuration = elapsed
        completion(nil, elapsed, numberOfMessages)
        NotificationCenter.default.post(name: .didSync, object: nil)
    }

    // MARK: Refresh

    private var _isRefreshing = false
    var isRefreshing: Bool { return self._isRefreshing }
    
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
                completion(nil, 0)
            }
            return
        }
        
        self._isRefreshing = true
        
        let elapsed = Date()
        self.utilityQueue.async {
            self.updateReceive(limit: load.rawValue) {
                [weak self] error in
                queue.async {
                    self?.notifyRefreshComplete(in: -elapsed.timeIntervalSinceNow,
                                                error: error,
                                                completion: completion)
                }
            }
        }
    }

    private func notifyRefreshComplete(in elapsed: TimeInterval,
                                       error: Error?,
                                       completion: @escaping RefreshCompletion)
    {
        self._isRefreshing = false
        self._statistics.lastRefreshDate = Date()
        self._statistics.lastRefreshDuration = elapsed
        completion(error, elapsed)
        NotificationCenter.default.post(name: .didRefresh, object: nil)
    }
    
    // MARK: Invites
    
    func redeemInvitation(to star: Star, completionQueue: DispatchQueue, completion: @escaping ErrorCompletion) {
        self.utilityQueue.async {
                        
            // Verify that we can connect to the pub, because go-ssb locks up while redeeming an invitation.
            // https://github.com/planetary-social/planetary-ios/issues/272
            star.testConnection { connectionSuccessful in
                guard connectionSuccessful else {
                    // TODO: make better error message
                    completion(GoBotError.unexpectedFault("Could not connect to Star."))
                    return
                }
                
                star.invite.withGoString { goStr in
                    if ssbInviteAccept(goStr) {
                        do {
                            let feed = star.feed
                            let address = star.address.multipeer
                            let redeemed = Date().timeIntervalSince1970 * 1000
                            try self.database.saveAddress(feed: feed, address: address, redeemed: redeemed)
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
        self.userInitiatedQueue.async {
            guard let identity = self._identity else {
                completionQueue.async {
                    completion(MessageIdentifier.null, BotError.notLoggedIn)
                }
                return
            }
            
            if UserDefaults.standard.bool(forKey: "prevent_feed_from_forks") {
                guard let numberOfMessagesInRepo = try? self.database.numberOfMessages(for: identity) else {
                    completionQueue.async {
                        completion(MessageIdentifier.null, GoBotError.unexpectedFault("Failed to access database"))
                    }
                    return
                }
                
                let knownNumberOfMessagesInKeychain = AppConfiguration.current?.numberOfPublishedMessages ?? 0
                
                guard numberOfMessagesInRepo >= knownNumberOfMessagesInKeychain else {
                    completionQueue.async {
                        completion(MessageIdentifier.null, BotError.notEnoughMessagesInRepo)
                    }
                    return
                }
            }
            self.bot.publish(content) { [weak self] key, error in
                if let error = error {
                    completionQueue.async { completion(MessageIdentifier.null, error) }
                    return
                }
                
                Log.info("Published message with key \(key ?? "nil")")
                
                // Copy the newly published post into the ViewDatabase immediately.
                do {
                    guard let self = self else {
                        completionQueue.async { completion(MessageIdentifier.null, BotError.notLoggedIn) }
                        return
                    }
                    let lastPostIndex = try self.database.largestSeqFromPublishedLog()
                    let publishedPosts = try self.bot.getPublishedLog(after: lastPostIndex)
                    try self.database.fillMessages(msgs: publishedPosts)
                    completionQueue.async { completion(key, nil) }
                } catch {
                    completionQueue.async { completion(MessageIdentifier.null, error) }
                }
            }
        }
    }

    func delete(message: MessageIdentifier, completion: @escaping ErrorCompletion) {
        var targetMessage: KeyValue? = nil
        do {
            targetMessage = try self.database.get(key: message)
        } catch {
            completion(GoBotError.duringProcessing("failed to get message", error))
            return
        }

        guard let msg = targetMessage else {
            var err: Error = ViewDatabaseError.unknownMessage(message)
            err = GoBotError.duringProcessing("delete: failed to get() from viewDB", err)
            completion(err)
            return
        }
        
        if msg.value.author != self._identity {
            // drop from view regardless of format
            do {
                try self.database.delete(message: message)
            } catch {
                completion(GoBotError.duringProcessing("failed to excute delete action", error))
                return
            }
        }

        guard msg.value.author.algorithm == .ggfeed else {
            completion(GoBotError.unexpectedFault("unsupported feed format for deletion"))
            return
        }
        
        guard msg.contentType == .post else {
            // we _could_ delete .about but we can't select them anyway... (we could display them on user profiles?)
            completion(ViewDatabaseError.unexpectedContentType("can only delete posts"))
            return
        }
        
        guard msg.value.author == self._identity else {
            // drop content directly / can't request others to do so
            do {
                try self.bot.nullContent(author: msg.value.author, sequence: UInt(msg.value.sequence))
            } catch {
                completion(GoBotError.duringProcessing("failed to null content", error))
                return
            }
            completion(nil)
            return
        }
        
        // publish signed drop-content-request for other peers
        let dcr = DropContentRequest(
            sequence: UInt(msg.value.sequence),
            hash: message)

        self.publish(content: dcr) {
            ref, err in
            // fillMessages will make it go away from the view
            completion(err)
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
            lastRxSeq = try self.database.largestSeqNotFromPublishedLog()
        } catch {
            throw GoBotError.duringProcessing("view query failed", error)
        }
        
        do {
            let repoStats = try self.bot.repoStatus()
            if repoStats.messages == 0 {
                return (lastRxSeq, 0)
            }
            let diff = Int(Int64(repoStats.messages)-1-lastRxSeq)
            if diff < 0 {
                throw GoBotError.unexpectedFault("needsViewFill: more msgs in view then in GoBot repo: \(lastRxSeq) (diff: \(diff))")
            }
            
            return (lastRxSeq, diff)
        } catch {
            throw GoBotError.duringProcessing("bot current failed", error)
        }
    }
    
    private func repairViewConstraints21012020(with author: Identity, current: Int64) -> (Analytics.BotRepair, Error?) {
        // fields we want to include in the tracked event
        var repair = Analytics.BotRepair(function: "ViewConstraints21012020",
                                         numberOfMessagesInDB: current,
                                         numberOfMessagesInRepo: self._statistics.repo.messageCount)

        // TODO: maybe make an enum for all these errors?
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

        for a in report.Authors {
            do {
                try self.database.delete(allFrom: a)
            } catch ViewDatabaseError.unknownAuthor {
                // after the viewdb schema bump, ppl that have this bug
                // only have it in the gobot after the update
                // therefore we can skip this if the viewdb is filling for the first time
                guard current == -1 else {
                    return (repair, GoBotError.unexpectedFault("[constraint violation] expected author from fsck report in viewdb"))
                }
                continue
            } catch {
                return (repair, GoBotError.duringProcessing("[constraint violation] unable to drop affected feed from viewdb", error))
            }
        }

        return (repair, nil)
    }
    
    // should only be called by refresh() (which does the proper completion on mainthread)
    private func updateReceive(limit: Int = 15000, completion: @escaping ErrorCompletion) {
        var current: Int64 = 0
        var diff: Int = 0

        do {
            (current, diff) = try self.needsViewFill()
        } catch {
            completion(error)
            return
        }
        
        guard diff > 0 else {
            // still might want to update privates
            #if DEBUG
            print("[rx log] viewdb already up to date.")
            #endif
            self.updatePrivate(completion: completion)
            return
        }
        
        // TOOD: redo until diff==0
        do {
            let msgs = try self.bot.getReceiveLog(startSeq: current+1, limit: limit)
            
            guard msgs.count > 0 else {
                print("warning: triggered update but got no messages from receive log")
                completion(nil)
                return
            }
            
            do {
                try self.database.fillMessages(msgs: msgs)
                                
                let params = [
                    "msg.count": msgs.count,
                    "first.timestamp": msgs[0].timestamp,
                    "last.timestamp": msgs[msgs.count-1].timestamp,
                    "last.hash":msgs[msgs.count-1].key
                    ] as [String : Any]

                Analytics.shared.trackBodDidUpdateDatabase(count: msgs.count,
                                                           firstTimestamp: msgs[0].timestamp,
                                                           lastTimestamp: msgs[msgs.count-1].timestamp,
                                                           lastHash: msgs[msgs.count-1].key)
                
                if diff < limit { // view is up2date now
                    completion(nil)
                    // disable private messages until there is UI for it AND ADD SQLCYPHER!!!111
                    //self.updatePrivate(completion: completion)
                } else {
                    #if DEBUG
                    print("#rx log# \(diff-limit) messages left in go-ssb offset log")
                    #endif
                    completion(nil)
                }
            } catch ViewDatabaseError.messageConstraintViolation(let author, let sqlErr) {
                let (repair, err) = self.repairViewConstraints21012020(with: author, current: current)

                Analytics.shared.trackBotDidRepair(databaseError: sqlErr,
                                                   error: err?.localizedDescription,
                                                   repair: repair)

                #if DEBUG
                print("[rx log] viewdb fill of aborted and repaired.")
                #endif
                completion(err)
            } catch {
                let err = GoBotError.duringProcessing("viewDB: message filling failed", error)
                Log.optional(err)
                CrashReporting.shared.reportIfNeeded(error: err)
                completion(err)
            }
        } catch {
            completion(error)
        }
    }
    
    private func updatePrivate(completion: @escaping ErrorCompletion) {
        var count: Int64 = 0
        do {
            let c = try self.database.stats(table: .privates)
            count = Int64(c)
            
            // TOOD: redo until diff==0
            let msgs = try self.bot.getPrivateLog(startSeq: count, limit: 1000)
            
            if msgs.count > 0 {
                try self.database.fillMessages(msgs: msgs, pms: true)
                
                print("[private log] private log filled with \(msgs.count) msgs (started at \(count))")
            }
            
            completion(nil)
        } catch {
            completion(error)
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
            self.bot.blobsAdd(data: data) {
                identifier, error in
                DispatchQueue.main.async {
                    completion(identifier, error)
                }
            }
        }
    }

    // TODO consider that having UIImage at this level requires UIKit
    // which might be inappropriate at this level
    @available(*, deprecated)
    func addBlob(jpegOf image: UIImage,
                 largestDimension: UInt? = nil,
                 completion: @escaping AddImageCompletion)
    {
        Thread.assertIsMainThread()

        // convenience closure to keep code cleaner
        let completionOnMain: AddImageCompletion = {
            image, error in
            DispatchQueue.main.async { completion(image, error) }
        }

        userInitiatedQueue.async {

            // encode image or return failures
            var image: UIImage? = image
            if let dimension = largestDimension                             { image = image?.resized(toLargestDimension: CGFloat(dimension)) }
            guard let uiimage = image else                                  { completionOnMain(nil, BotError.blobUnsupportedFormat); return }
            guard let data = uiimage.jpegData(compressionQuality: 0.5) else { completionOnMain(nil, BotError.blobUnsupportedFormat); return }
            guard data.count <= self.maxBlobBytes else                      { completionOnMain(nil, BotError.blobMaximumSizeExceeded); return }

            // add to log and return Image if successful
            self.bot.blobsAdd(data: data) {
                identifier, error in
                CrashReporting.shared.reportIfNeeded(error: error)
                if Log.optional(error) { completionOnMain(nil, error); return }
                let image = Image(link: identifier, jpegImage: uiimage, data: data)
                completionOnMain(image, nil)
            }
        }
    }

    func data(for identifier: BlobIdentifier,
              completion: @escaping ((BlobIdentifier, Data?, Error?) -> Void))
    {
        Thread.assertIsMainThread()

        guard identifier.isValidIdentifier else {
            completion(identifier, nil, BotError.blobInvalidIdentifier)
            return
        }

        userInitiatedQueue.async {

            // get non-empty data from blob storage
            do {
                let data = try self.bot.blobGet(ref: identifier)
                DispatchQueue.main.async {
                    if data.isEmpty { completion(identifier, nil, BotError.blobUnavailable) }
                    else            { completion(identifier, data, nil) }
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
            try FileManager.default.createDirectory(at: repoURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            try FileManager.default.copyItem(at: url, to: repoURL)
            completion(repoURL, nil)
        } catch let error {
            completion(nil, error)
        }
    }
    
    func store(data: Data, for identifier: BlobIdentifier, completion: @escaping BlobsStoreCompletion) {
        let url: URL
        do {
            url = try self.bot.blobFileURL(ref: identifier)
        } catch let error {
            completion(nil, error)
            return
        }

        utilityQueue.async {
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                        withIntermediateDirectories: true,
                                                        attributes: nil)
                try data.write(to: url, options: .atomic)
                completion(url, nil)
            } catch let error {
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
        Thread.assertIsMainThread()
        guard let user = self._identity else {
            completion(nil, BotError.notLoggedIn)
            return
        }
        self.about(identity: user, completion: completion)
    }
    
    
    func about(queue: DispatchQueue, identity: Identity, completion: @escaping AboutCompletion) {
        userInitiatedQueue.async {
            do {
                let a = try self.database.getAbout(for: identity)
                queue.async {
                    if a?.identity == self._identity { self._about = a }
                    completion(a, nil)
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

    // MARK: Contacts

    func follow(_ identity: Identity, completion: @escaping ContactCompletion) {
        identity.assertNotMe()
        let contact = Contact(contact: identity, following: true)
        self.publish(content: contact) {
            _, error in
            let contactOrNilIfError = (error == nil ? contact : nil)
            completion(contactOrNilIfError, error)
        }
    }

    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion) {
        identity.assertNotMe()
        let contact = Contact(contact: identity, following: false)
        self.publish(content: contact) {
            _, error in
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
                let who = try self.database.getBidirectionalFollows(feed: identity)
                DispatchQueue.main.async { completion(who, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }
    
    func blocks(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let who = try self.database.getBlocks(feed: identity)
                DispatchQueue.main.async {
                    completion(who, nil)
                }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }
    
    func blockedBy(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let who = try self.database.blockedBy(feed: identity)
                DispatchQueue.main.async {
                    completion(who, nil)
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
        self.publish(content: block) {
            ref, err in
            if let e = err { completion("", e); return; }

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

            completion(ref, nil)
            NotificationCenter.default.post(name: .didBlockUser, object: identity)
        }
    }

    func unblock(_ identity: Identity, completion: @escaping PublishCompletion) {
        self.publish(content: Contact(contact: identity, blocking: false)) {
            ref, err in
            if let e = err {
                completion("", e);
                return;
            }
            completion(ref, nil)
        }
    }

    // MARK: Feeds

    // old recent
    func recent(completion: @escaping PaginatedCompletion) {
        userInitiatedQueue.async {
            do {
                let ds = try self.database.paginated(onlyFollowed: true)
                DispatchQueue.main.async { completion(ds, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }
    
    func keyAtRecentTop(queue: DispatchQueue, completion: @escaping (MessageIdentifier?) -> Void) {
        userInitiatedQueue.async {
            do {
                let key = try self.database.paginatedTop(onlyFollowed: true)
                queue.async {
                    completion(key)
                }
            } catch {
                queue.async {
                    completion(nil)
                }
            }
        }
    }
    
    // posts from everyone, not just who you follow
    func everyone(completion: @escaping PaginatedCompletion) {
        userInitiatedQueue.async {
            do {
                let msgs = try self.database.paginated(onlyFollowed: false)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error)  }
            }
        }
    }
    
    func keyAtEveryoneTop(queue: DispatchQueue, completion: @escaping (MessageIdentifier?) -> Void) {
        userInitiatedQueue.async {
            do {
                let key = try self.database.paginatedTop(onlyFollowed: false)
                queue.async {
                    completion(key)
                }
            } catch {
                queue.async {
                    completion(nil)
                }
            }
        }
    }

    func thread(keyValue: KeyValue, completion: @escaping ThreadCompletion) {
        assert(keyValue.value.content.isPost)
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            if let rootKey = keyValue.value.content.post?.root {
                do {
                    let root = try self.database.get(key: rootKey)
                    let replies = try self.database.getRepliesTo(thread: root.key)
                    DispatchQueue.main.async {
                        completion(root, StaticDataProxy(with:replies), nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, StaticDataProxy(), error)
                    }
                }
            } else {
                self.internalThread(rootKey: keyValue.key, completion: completion)
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
            let root = try self.database.get(key: rootKey)
            let replies = try self.database.getRepliesTo(thread: rootKey)
            DispatchQueue.main.async {
                completion(root, StaticDataProxy(with:replies), nil)
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
                let p = StaticDataProxy(with:messages)
                DispatchQueue.main.async { completion(p, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    // TODO consider a different form that returns a tuple of arrays
    func reports(queue: DispatchQueue, completion: @escaping (([Report], Error?) -> Void)) {
        userInitiatedQueue.async {
            do {
                let all = try self.database.reports()
                queue.async {
                    completion(all, nil)
                }
            } catch {
                queue.async {
                    completion([],error)
                }
            }
        }
    }

    func feed(identity: Identity, completion: @escaping PaginatedCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                let ds = try self.database.paginated(feed: identity)
                DispatchQueue.main.async { completion(ds, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    // MARK: Hashtags

    func hashtags(completion: @escaping HashtagsCompletion) {
        Thread.assertIsMainThread()
        userInitiatedQueue.async {
            do {
                var hashtags = try self.database.hashtags()
                hashtags.reverse()
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
                let keyValues = try self.database.messagesForHashtag(name: hashtag.name)
                let p = StaticDataProxy(with: keyValues)
                DispatchQueue.main.async { completion(p, nil) }
            } catch {
                DispatchQueue.main.async { completion(StaticDataProxy(), error) }
            }
        }
    }

    // MARK: Statistics

    private var _statistics = MutableBotStatistics()
    
    var statistics: BotStatistics {
        let counts = try? self.bot.repoStatus()
        let sequence = try? self.database.stats(table: .messagekeys)
        
        var ownMessages = -1
        if let identity = self._identity, let omc = try? self.database.numberOfMessages(for: identity) {
            ownMessages = omc
        }
        
        var fc: Int = -1
        if let feedCount = counts?.feeds { fc = Int(feedCount) }
        var mc: Int = -1
        if let msgs = counts?.messages { mc = Int(msgs) }
        self._statistics.repo = RepoStatistics(path: self.bot.currentRepoPath,
                                               feedCount: fc,
                                               messageCount: mc,
                                               numberOfPublishedMessages: ownMessages,
                                               lastHash: counts?.lastHash ?? "")
        
        let connectionCount = self.bot.openConnections()
        let openConnections = self.bot.openConnectionList()
        
        self._statistics.peer = PeerStatistics(count: openConnections.count,
                                               connectionCount: connectionCount,
                                               identities: openConnections,
                                               open: openConnections)

        self._statistics.db = DatabaseStatistics(lastReceivedMessage: sequence ?? -3)
        
        return self._statistics
    }
    
    func statistics(queue: DispatchQueue, completion: @escaping StatisticsCompletion) {
        self.utilityQueue.async {
            let counts = try? self.bot.repoStatus()
            let sequence = try? self.database.stats(table: .messagekeys)

            var ownMessages = -1
            if let identity = self._identity, let omc = try? self.database.numberOfMessages(for: identity) {
                ownMessages = omc
            }
            
            var fc: Int = -1
            if let feedCount = counts?.feeds { fc = Int(feedCount) }
            var mc: Int = -1
            if let msgs = counts?.messages { mc = Int(msgs) }
            self._statistics.repo = RepoStatistics(path: self.bot.currentRepoPath,
                                                   feedCount: fc,
                                                   messageCount: mc,
                                                   numberOfPublishedMessages: ownMessages,
                                                   lastHash: counts?.lastHash ?? "")
            
            let connectionCount = self.bot.openConnections()
            let openConnections = self.bot.openConnectionList()
            
            self._statistics.peer = PeerStatistics(count: openConnections.count,
                                                   connectionCount: connectionCount,
                                                   identities: openConnections,
                                                   open: openConnections)

            self._statistics.db = DatabaseStatistics(lastReceivedMessage: sequence ?? -3)
            
            let statistics = self._statistics
            queue.async {
                completion(statistics)
            }
        }
    }
    
    func lastReceivedTimestam() throws -> Double {
        return Double(try self.database.lastReceivedTimestamp())
    }
    

    
  
    
    // MARK: Preloading
    
    func preloadFeed(at url: URL, completion: @escaping ErrorCompletion) {
        userInitiatedQueue.async {
            do {
                let data = try Data(contentsOf: url, options: .mappedIfSafe)
                do {
                    let msgs = try JSONDecoder().decode([KeyValue].self, from: data)

                    var lastRxSeq: Int64 = try self.database.minimumReceivedSeq()
                    
                    let newMesgs = msgs.map { (msg: KeyValue) -> KeyValue in
                        lastRxSeq = lastRxSeq - 1
                        return KeyValue(key: msg.key,
                                        value: msg.value,
                                        timestamp: msg.timestamp,
                                        receivedSeq: lastRxSeq,
                                        hashedKey: msg.key.sha256hash
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
    
}
