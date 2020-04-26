//
//  GoBotAPI.swift
//  FBTT
//
//  Created by Henry Bubert on 13.02.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit


extension String {
    func withGoString<R>(_ call: (gostring_t) -> R) -> R {
        func helper(_ pointer: UnsafePointer<Int8>?, _ call: (gostring_t) -> R) -> R {
            return call(gostring_t(p: pointer, n: utf8.count))
        }
        return helper(self, call)
    }
}


fileprivate let refreshDelay = DispatchTimeInterval.milliseconds(125)

class GoBot: Bot {

    // TODO https://app.asana.com/0/914798787098068/1122165003408769/f
    // TODO expose in API?
    private let maxBlobBytes = 1024 * 1024 * 8
    
    let name = "GoBot"
    var version: String { return self.bot.version }
    
    static let shared = GoBot()

    private var _identity: Identity? = nil
    var identity: Identity? { return self._identity }

    private let queue: DispatchQueue
    var follows: [FeedIdentifier] = []
    var withoutPubs: [FeedIdentifier] = []
    var followedBy: [FeedIdentifier] = []
    var friends: [Identity] = []
    var blocks: [FeedIdentifier] = []
    var anyBlocks: Bool = false
    
    // TODO https://app.asana.com/0/914798787098068/1120595810221102/f
    // TODO Make GoBotAPI.database and GoBotAPI.bot private
    let bot :GoBotInternal
    let database = ViewDatabase()

    init() {
        self.queue = DispatchQueue(label: "GoBot",
                              qos: .utility,
                              attributes: .concurrent,
                              autoreleaseFrequency: .workItem,
                              target: nil)
        self.bot = GoBotInternal(self.queue)
    }

    // MARK: App Lifecycle

    func resume()  {
        //Thread.assertIsMainThread()
        self.queue.async {
            self.bot.dialSomePeers()
        }
    }

    func suspend() {
        Thread.assertIsMainThread()
        self.queue.async {
            self.bot.disconnectAll()
        }
    }

    func exit() {
        Thread.assertIsMainThread()
        self.queue.async {
            self.bot.disconnectAll()
        }
    }

    // MARK: Login/Logout
    
    func createSecret(completion: SecretCompletion) {
        //Thread.assertIsMainThread()
        
        guard let kp = ssbGenKey() else {
            completion(nil, GoBotError.unexpectedFault("createSecret failed"))
            return
        }
        let sec = Secret(from: String(cString: kp))
        free(kp)
        completion(sec, nil)
    }
    
    func login(network: NetworkKey, hmacKey: HMACKey?, secret: Secret, completion: @escaping ErrorCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            var err: Error? = nil
            defer {
                DispatchQueue.main.async {
                    if let e = err { Log.unexpected(.botError, "[GoBot.login] failed: \(e)") }
                    completion(err)
                }
            }

            if self._identity != nil {
                if secret.identity == self._identity {
                    return
                }
                err = BotError.alreadyLoggedIn
                return
            }

            let appSupportDirs = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
            if appSupportDirs.count < 1 {
                err = GoBotError.unexpectedFault("no support dir")
                return
            }

            let repoPrefix = appSupportDirs[0]
                .appending("/FBTT")
                .appending("/"+network.hexEncodedString())

            #if DEBUG
            // used for locating the files in the simulator
            print("===> starting gobot with prefix: \(repoPrefix)")
            #endif
            if let loginErr = self.bot.login(network: network, hmacKey: hmacKey, secret: secret, pathPrefix: repoPrefix) {
                err = loginErr
                return
            }

            if !self.database.isOpen() {
                do {
                    try self.database.open(path: repoPrefix, user: secret.identity)
                    err = nil
                } catch {
                    err = error
                    return
                }
            } else {
                Log.unexpected(.botError, "\(#function) warning: database still open")
            }

            // create connections a bit after login completed
            self.queue.asyncAfter(deadline: .now() + .seconds(5)) {
                self.bot.dial(atLeast: 2)
            }

            // TODO this does not always get set in time
            // TODO maybe this should be done in defer?
            self._identity = secret.identity
        }
        return
    }
    
    func logout(completion: @escaping ErrorCompletion) {
        Thread.assertIsMainThread()
        if self._identity == nil {
            DispatchQueue.main.async { completion(BotError.notLoggedIn) }
            return
        }
        self.bot.logout()
        _ = self.database.close()
        self._identity = nil
        DispatchQueue.main.async { completion(nil) }
    }

    
    // MARK: Sync
    
    func knownPubs(completion: @escaping KnownPubsCompletion) {
       //Thread.assertIsMainThread()
         self.queue.async {
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

    private var _isSyncing = false
    var isSyncing: Bool { return self._isSyncing }

    // TODO https://app.asana.com/0/914798787098068/1121148308653004/f
    // TODO make sync not return immediately because it's querying peers
    // note that dialSomePeers() is called, then the completion is called
    // some time later, this is a workaround until we can figure out how
    // to determine peer connection status and progress
    func sync(queue: DispatchQueue, completion: @escaping SyncCompletion) {
        guard self.bot.isRunning() else {
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

        self.queue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialSomePeers()
            let after = self.repoNumberOfMessages()
            let new = after - before
            queue.async {
                self.notifySyncComplete(in: -elapsed.timeIntervalSinceNow,
                                        numberOfMessages: new,
                                        completion: completion)
            }
        }
    }

    func syncNotifications(completion: @escaping SyncCompletion) {
        //assert(Thread.isMainThread)
        guard self.bot.isRunning() else { completion(GoBotError.unexpectedFault("bot not started"), 0, 0); return }
        guard self._isSyncing == false else { completion(nil, 0, 0); return }

        self._isSyncing = true
        let elapsed = Date()

        self.queue.async {
            let before = self.repoNumberOfMessages()
            self.bot.dialForNotifications()
            let after = self.repoNumberOfMessages()
            let new = after - before
            self.notifySyncComplete(in: -elapsed.timeIntervalSinceNow,
                                    numberOfMessages: new,
                                    completion: completion)
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
        NotificationCenter.default.post(Notification.didStartViewRefresh())
        self._isRefreshing = true
        let elapsed = Date()
        self.queue.async {
            self.updateReceive(limit: load.rawValue) {
                [weak self] error in
                queue.async {
                    self?.notifyRefreshComplete(in: -elapsed.timeIntervalSinceNow,
                                                error: error,
                                                completion: completion)
                    NotificationCenter.default.post(name: .didFinishDatabaseProcessing, object: nil)
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
    
    func inviteRedeem(token: String, completion: @escaping ErrorCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            token.withGoString {
                goStr in
                let worked = ssbInviteAccept(goStr)

                var err: Error? = nil
                if !worked { // TODO: find a nicer way to pass errors back on the C-API
                    err = GoBotError.unexpectedFault("invite did not work. Maybe try again?")
                }
                DispatchQueue.main.async { completion(err) }
            }
        }
    }

    // MARK: Publish
    private var lastPublishFireTime = DispatchTime.now()

    func publish(content: ContentCodable, completion: @escaping PublishCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            self.bot.publish(content) {
                [weak self] key, error in
                if let error = error {
                    DispatchQueue.main.async { completion(MessageIdentifier.null, error) }
                    return
                }

                // debounce refresh calls (at most one every 125ms)
                let now = DispatchTime.now()
                self?.lastPublishFireTime = now
                let refreshTime: DispatchTime = now + refreshDelay

                self?.queue.asyncAfter(deadline: refreshTime) {
                    guard let lastFireTime = self?.lastPublishFireTime else {
                        return
                    }

                    let when: DispatchTime = lastFireTime + refreshDelay
                    let now = DispatchTime.now()

                    // the call happend after the given timeout (refreshDelay)
                    if now.rawValue >= when.rawValue {
                        self?.internalRefresh(load: .short, queue: .global(qos: .userInteractive)) { // do a refresh, then return to the caller
                            error, _ in
                            Log.optional(error)
                            CrashReporting.shared.reportIfNeeded(error: error)
                            // finally, return back to the UI
                            DispatchQueue.main.async { completion(key, nil) }
                        }
                    } else {
                        // don't do a view refresh, just return to the caller
                        // Q: is this actually called for each asyncAfter call?
                        DispatchQueue.main.async { completion(key, nil) }
                    }
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


    // returns (current, diff)
    func needsViewFill() throws -> (Int64, Int) {
        var lastRxSeq: Int64 = 0
        do {
            lastRxSeq = try self.database.lastReceivedSeq()
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
    
    private func repairViewConstraints21012020(with author: Identity, current: Int64) -> (AnalyticsEnums.Params, Error?) {
        // fields we want to include in the tracked event
        var params: AnalyticsEnums.Params = [
            "function": "ViewConstraints21012020",
            "viewdb_current": current,
            "repo_messages_count": self._statistics.repo.messageCount,
        ]
        // TODO: maybe make an enum for all these errors?
        let (worked, maybeReport) = self.bot.fsckAndRepair()
        guard worked else {
            return (params, GoBotError.unexpectedFault("[constraint violation] failed to heal gobot repository"))
        }

        guard let report = maybeReport else { // there was nothing to repair?
            return (params, GoBotError.unexpectedFault("[constraint violation] viewdb error but nothing to repair"))
        }

        params["reported_authors"] = report.Authors.count
        params["reported_messages"] = report.Messages

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
                    return (params, GoBotError.unexpectedFault("[constraint violation] expected author from fsck report in viewdb"))
                }
                continue
            } catch {
                return (params, GoBotError.duringProcessing("[constraint violation] unable to drop affected feed from viewdb", error))
            }
        }

        return (params, nil)
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
        
        if diff == 0 {
            // still might want to update privates
            self.updatePrivate(completion: completion)
            return
        }
        
        // TOOD: redo until diff==0
        self.bot.getReceiveLog(startSeq: current+1, limit: limit) { msgs, err in
            if let e = err {
                completion(e)
                return
            }
            if msgs.count == 0 {
                print("warning: triggered update but got no messages from receive log")
                completion(nil)
                return
            }

            do {
                try self.database.fillMessages(msgs: msgs)
            } catch ViewDatabaseError.messageConstraintViolation(let author, let sqlErr) {
                var (params, err) = self.repairViewConstraints21012020(with: author, current: current)
                // add original SQL error
                params["sql_error"] = sqlErr
                if let e = err {
                    params["repair_failed"] = e.localizedDescription
                }

                Analytics.track(event: .did,
                                 element: .bot,
                                 name: AnalyticsEnums.Name.repair.rawValue,
                                 params: params)

                 // trying to re-sync the feed
                self.bot.dial(atLeast: 1)
                #if DEBUG
                print("[rx log] viewdb fill of aborted and repaired.")
                #endif
                completion(err)
                return
            } catch {
                let err = GoBotError.duringProcessing("viewDB: message filling failed", error)
                Log.optional(err)
                CrashReporting.shared.reportIfNeeded(error: err)
                completion(err)
                return
            }

            #if DEBUG
            print("[rx log] viewdb filled with \(msgs.count) messages.")
            #endif
            if diff < limit { // view is up2date now
                self.updatePrivate(completion: completion)
            } else {
                #if DEBUG
                print("#rx log# \(diff-limit) messages left in go-ssb offset log")
                #endif
                completion(nil)
            }
        }
    }
    
    private func updatePrivate(completion: @escaping ErrorCompletion) {
        var count: Int64 = 0
        do {
            let c = try self.database.stats(table: .privates)
            count = Int64(c)
        } catch {
            completion(error)
            return
        }
        // TOOD: redo until diff==0
        self.bot.getPrivateLog(startSeq: count, limit: 1000) { msgs, err in
            if let e = err {
                completion(e)
                return
            }

            do {
                try self.database.fillMessages(msgs: msgs, pms: true)
            } catch {
                completion(error)
                return
            }
            if msgs.count > 0 {
                print("[private log] private log filled with \(msgs.count) msgs (started at \(count))")
            }
            completion(nil)
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
        self.queue.async {
            self.bot.blobsAdd(data: data) {
                identifier, error in
                DispatchQueue.main.async {
                    Analytics.trackBotDidPublish(identifier, numberOfBytes: data.count)
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

        self.queue.async {

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
        //Thread.assertIsMainThread()

        guard identifier.isValidIdentifier else {
            completion(identifier, nil, BotError.blobInvalidIdentifier)
            return
        }

        self.queue.async {

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
                    self.sync(queue: .global(qos: .background)) { _, _, _ in }
                }
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
    var about: About? { return self._about }

    func about(completion: @escaping AboutCompletion) {
        //Thread.assertIsMainThread()
        guard let user = self._identity else {
            completion(nil, BotError.notLoggedIn)
            return
        }
        self.about(identity: user, completion: completion)
    }
    
    func about(identity: Identity, completion: @escaping AboutCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let a = try self.database.getAbout(for: identity)
                DispatchQueue.main.async {
                    if a?.identity == self._identity { self._about = a }
                    completion(a, nil)
                }
            } catch {
                DispatchQueue.main.async { completion(nil, error) }
            }
        }
    }

    func abouts(identities: Identities, completion: @escaping AboutsCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            var abouts: [About] = []
            for identity in identities {
                if let about = try? self.database.getAbout(for: identity) {
                    abouts += [about]
                }
            }
            DispatchQueue.main.async { completion(abouts, nil) }
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
        //resetting the in memory cache of follows
        self.follows=[]
    }

    func unfollow(_ identity: Identity, completion: @escaping ContactCompletion) {
        identity.assertNotMe()
        let contact = Contact(contact: identity, following: false)
        self.publish(content: contact) {
            _, error in
            let contactOrNilIfError = (error == nil ? contact : nil)
            completion(contactOrNilIfError, error)
        }
        //resetting the in memory cache of follows
        self.follows=[]
    }

    func follows(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        //Thread.assertIsMainThread()
        //this should be refactored, i gave up on being clever. - rabble
        if identity == self.identity {
            self.queue.async {
                 if self.follows.isEmpty {
                     do {
                         self.follows = try self.database.getFollows(feed: identity)
                         self.withoutPubs = self.follows.withoutPubs()
                         DispatchQueue.main.async { completion(self.withoutPubs, nil) }
                     } catch {
                         DispatchQueue.main.async { completion([], error) }
                     }
                 } else {
                     DispatchQueue.main.async { completion(self.withoutPubs, nil) }
                 }
             }
        } else {
            self.queue.async {
                do {
                    let follows = try self.database.getFollows(feed: identity)
                    let withoutPubs = follows.withoutPubs()
                    DispatchQueue.main.async { completion(withoutPubs, nil) }
                } catch {
                    DispatchQueue.main.async { completion([], error) }
                }
            }
        }
    }
    
    func followedBy(identity: Identity, completion: @escaping ContactsCompletion) {
        //Thread.assertIsMainThread()
        //this should be refactored, i gave up on being clever. - rabble
        if identity == self.identity {
            self.queue.async {
                if self.followedBy.isEmpty {
                    do {
                        let follows: [Identity] = try self.database.followedBy(feed: identity)
                        let withoutPubs = follows.withoutPubs()
                        self.followedBy = withoutPubs
                        DispatchQueue.main.async { completion(self.followedBy, nil) }
                    } catch {
                        DispatchQueue.main.async { completion([], error) }
                    }
                } else {
                    DispatchQueue.main.async { completion(self.followedBy, nil) }
                }
            }
        } else {
            do {
                let follows: [Identity] = try self.database.followedBy(feed: identity)
                let withoutPubs = follows.withoutPubs()
                DispatchQueue.main.async { completion(withoutPubs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }

        }
    }
    
    func friends(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        //Thread.assertIsMainThread()
        if identity == self.identity {
            self.queue.async {
                if self.friends.isEmpty {
                    do {
                        let who = try self.database.getBidirectionalFollows(feed: identity)
                        self.friends = who
                        DispatchQueue.main.async { completion(self.friends, nil) }
                    } catch {
                        DispatchQueue.main.async { completion([], error) }
                    }
                } else {
                    DispatchQueue.main.async { completion(self.friends, nil) }
                }
            }
        } else {
            do {
                let who = try self.database.getBidirectionalFollows(feed: identity)
                DispatchQueue.main.async { completion(who, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }

        }
    }
    
    func blocks(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        //Thread.assertIsMainThread()
        if identity == self.identity {
            self.queue.async {
                if self.blocks.isEmpty && self.anyBlocks  {
                    do {
                        let who = try self.database.getBlocks(feed: identity)
                        self.blocks = who
                        self.anyBlocks = true
                        DispatchQueue.main.async { completion(self.blocks, nil) }
                    } catch {
                        DispatchQueue.main.async {
                            completion([], error)
                        }
                    }
                } else {
                    DispatchQueue.main.async { completion(self.blocks, nil) }
                }
            }
        } else {
            do {
                let who = try self.database.getBlocks(feed: identity)
                DispatchQueue.main.async { completion(who, nil) }
            } catch {
                DispatchQueue.main.async {
                    completion([], error)
                }
            }
        }
    }
    
    func blockedBy(identity: FeedIdentifier, completion: @escaping ContactsCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
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
        //resetting the in memory cache of blocks
        self.blocks=[]
        self.anyBlocks=false
    }

    func unblock(_ identity: Identity, completion: @escaping PublishCompletion) {
        self.publish(content: Contact(contact: identity, blocking: false)) {
            ref, err in
            if let e = err {
                completion("", e);
                return;
            }

            // we implement real feed delete now, so we will need to trigger a sync to fetch the feed again
            // TODO: Do we need refresh here
            self.bot.dial(atLeast: 2)
            self.refresh(load: .short, queue: .main) {
                err, _ in
                Log.optional(err)
                CrashReporting.shared.reportIfNeeded(error: err)
                completion(ref, nil)
                NotificationCenter.default.post(name: .didUnblockUser, object: identity)
            }
        }
        //resetting the in memory cache of blocks
        self.blocks=[]
        self.anyBlocks=false
    }

    // MARK: Feeds

    func recent(newer than: Date, count: Int, completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let msgs = try self.database.recentPosts(newer: than, limit: count)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }
    
    func recent(older than: Date, count: Int, wantPrivate: Bool, completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let msgs = try self.database.recentPosts(older: than, limit: count)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }
    
    // old recent
    func recent(completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let msgs = try self.database.recentPosts(limit: 200)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error)  }
            }
        }
    }
    
    // posts from everyone, not just who you follow
    func everyone(completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let msgs = try self.database.recentPosts(limit: 200, onlyFollowed: false)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error)  }
            }
        }
    }
    

    

    func thread(keyValue: KeyValue, completion: @escaping ThreadCompletion) {
        assert(keyValue.value.content.isPost)
        //Thread.assertIsMainThread()
        self.queue.async {
            if let rootKey = keyValue.value.content.post?.root {
                do {
                    let root = try self.database.get(key: rootKey)
                    let replies = try self.database.getRepliesTo(thread: root.key)
                    DispatchQueue.main.async {
                        completion(root, replies, nil)
                    }
                } catch {
                    DispatchQueue.main.async {
                        completion(nil, [], error)
                    }
                }
            } else {
                self.internalThread(rootKey: keyValue.key, completion: completion)
            }
        }
    }

    func thread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            self.internalThread(rootKey: rootKey, completion: completion)
        }
    }

    private func internalThread(rootKey: MessageIdentifier, completion: @escaping ThreadCompletion) {
        do {
            let root = try self.database.get(key: rootKey)
            let replies = try self.database.getRepliesTo(thread: rootKey)
            DispatchQueue.main.async {
                completion(root, replies, nil)
            }
        } catch {
            DispatchQueue.main.async {
                completion(nil, [], error)
            }
        }
    }

    func mentions(completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let messages = try self.database.mentions(limit: 1000)
                DispatchQueue.main.async { completion(messages, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    // TODO consider a different form that returns a tuple of arrays
    func notifications(completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                /* TODO:
                I _think_ right now it should be fast enough to union and sort contacts,
                mentions and replies in application space.

                butt!! we need to revisit this before launch, union and sort them in sql
                and then apply similar pagination as with recentPosts().
                */

                var all: [KeyValue] = []
                // TODO: optimize query
                // var replies = try self.database.getRepliesToMyThreads(limit: 10)
                // if let me = self.identity { replies = replies.excluding(me) }
                // all.append(contentsOf: replies)

                let mentions = try self.database.mentions(limit: 50)
                all.append(contentsOf: mentions)

                let contacts: [KeyValue] = try self.database.followedBy(feed: self._identity!, limit: 50)
                all.append(contentsOf: contacts)

                let sorted = all.sortedByDateDescending()
                DispatchQueue.main.async { completion(sorted, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    func feed(identity: Identity, completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let msgs = try self.database.feed(for: identity)
                DispatchQueue.main.async { completion(msgs, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    // MARK: Hashtags

    func hashtags(completion: @escaping HashtagsCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                var hashtags = try self.database.hashtags()
                hashtags.reverse()
                DispatchQueue.main.async { completion(hashtags, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    func posts(with hashtag: Hashtag, completion: @escaping FeedCompletion) {
        //Thread.assertIsMainThread()
        self.queue.async {
            do {
                let keyValues = try self.database.messagesForHashtag(name: hashtag.name)
                DispatchQueue.main.async { completion(keyValues, nil) }
            } catch {
                DispatchQueue.main.async { completion([], error) }
            }
        }
    }

    // MARK: Statistics

    private var _statistics = MutableBotStatistics()
    
    var statistics: BotStatistics {
        let counts = try? self.bot.repoStatus()
        let sequence = try? self.database.stats(table: .messagekeys)

        var fc: Int = -1
        if let feedCount = counts?.feeds { fc = Int(feedCount) }
        var mc: Int = -1
        if let msgs = counts?.messages { mc = Int(msgs) }
        self._statistics.repo = RepoStatistics(path: self.bot.currentRepoPath,
                                               feedCount: fc,
                                               messageCount: mc,
                                               lastReceivedMessage: sequence ?? -3)
        let identities = self.bot.peerIdentities

        let open = self.bot.openConnectionList()
        var openWithIdentities: [(String, Identity)] = []
        for peer in open {
            if let id = self.database.identityFromPublicKey(pubKey: peer.1) {
                openWithIdentities.append((peer.0, id))
            }
        }

        self._statistics.peer = PeerStatistics(count: identities.count,
                                               connectionCount: self.bot.openConnections(),
                                               identities: openWithIdentities, // just faking to see some data
                                               open: openWithIdentities)
        
        return self._statistics
    }
    
    func statistics(completion: @escaping StatisticsCompletion) {
        self.queue.async {
            let counts = try? self.bot.repoStatus()
            let sequence = try? self.database.stats(table: .messagekeys)

            var fc: Int = -1
            if let feedCount = counts?.feeds { fc = Int(feedCount) }
            var mc: Int = -1
            if let msgs = counts?.messages { mc = Int(msgs) }
            self._statistics.repo = RepoStatistics(path: self.bot.currentRepoPath,
                                                   feedCount: fc,
                                                   messageCount: mc,
                                                   lastReceivedMessage: sequence ?? -3)
            let identities = self.bot.peerIdentities

            let open = self.bot.openConnectionList()
            var openWithIdentities: [(String, Identity)] = []
            for peer in open {
                if let id = self.database.identityFromPublicKey(pubKey: peer.1) {
                    openWithIdentities.append((peer.0, id))
                }
            }

            self._statistics.peer = PeerStatistics(count: identities.count,
                                                   connectionCount: self.bot.openConnections(),
                                                   identities: openWithIdentities, // just faking to see some data
                                                   open: openWithIdentities)
            
            let statistics = self._statistics
            DispatchQueue.main.async {
                completion(statistics)
            }
        }
    }
}
