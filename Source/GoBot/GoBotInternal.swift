//
//  GoBot.swift
//  FBTT
//
//  Created by Henry Bubert on 22.01.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit
import Logger
import CrashReporting

// get's called with the size and the hash (might return a bool just as a demo of passing data back)
typealias CBlobsNotifyCallback = @convention(c) (Int64, UnsafePointer<Int8>?) -> Bool

// get's called with the messages left to process
typealias CFSCKProgressCallback = @convention(c) (Float64, UnsafePointer<Int8>?) -> Void

// get's called with a token and an expiry date as unix timestamp
typealias CPlanetaryBearerTokenCallback = @convention(c) (UnsafePointer<Int8>?, Int64) -> Void

/// An abstract representation of a peer that we can replicate with.
/// 
/// Note: This model only really supports peers we talk to over secret handshake and the IP protocol. Much of the stack
/// has been upgraded to support the new `MultiserverAddress` format which is more flexible.
struct Peer {
    let tcpAddr: String
    let pubKey: Identity
    
    init(tcpAddr: String, pubKey: Identity) {
        self.tcpAddr = tcpAddr
        self.pubKey = pubKey
    }
    
    var multiserverAddress: MultiserverAddress? {
        MultiserverAddress(string: "net:\(tcpAddr)~shs:\(pubKey.id)")
    }
}

// used to drain a single user feed
private struct FeedLogRequest: Codable {
    let feed: Identity
    let sequence: Int
    let limit: Int
    let keys: Bool
}

struct ScuttlegobotRepoCounts: Decodable {
    let messages: UInt
    let feeds: UInt
    let lastHash: String
}

struct ScuttlegobotBlobWant: Decodable {
    let Ref: String
    let Dist: Int
}

struct ScuttlegobotPeerStatus: Decodable {
    let Addr: String
    let Since: String
}

struct ScuttlegobotBotStatus: Decodable {
    let Root: Int
    let Peers: [ScuttlegobotPeerStatus]
    let Blobs: [ScuttlegobotBlobWant]
}

enum ScuttlegobotFSCKMode: UInt32 {

    // compares the message count of a feed with the sequence number of last message of a feed
    case FeedLength = 1

    // goes through all the messages and makes sure the sequences increament correctly for each feed
    case Sequences = 2
}

struct ScuttlegobotHealReport: Decodable {
    let Authors: [Identity]
    let Messages: UInt32
}

private struct GoBotConfig: Encodable {
    let AppKey: String
    let HMACKey: String
    let KeyBlob: String
    let Repo: String
    let ListenAddr: String
    let Hops: UInt // setting this value to 0 means "a person that you follow" (1 hop away), therefore this value should be understood slightly differently than in the case of some other clients
    let SchemaVersion: UInt

    let ServicePubs: [Identity]? // identities of services which supply planetary specific services

    #if DEBUG
    let Testing = true
    #else
    let Testing = false
    #endif
}

class GoBotInternal {

    var currentRepoPath: String { self.repoPath }
    private var repoPath: String = "/tmp/FBTT/unset"
    
    let name = "GoBot"

    var version: String {
        guard let v = ssbVersion() else {
            return "binding error"
        }
        return String(cString: v)
    }

    private let queue: DispatchQueue

    init(_ queue: DispatchQueue) {
        self.queue = queue
    }

    var isRunning: Bool {
        ssbBotIsRunning()
    }

    private var currentNetwork: SSBNetwork?

    var getNetworkKey: NetworkKey? {
        self.currentNetwork?.key
    }

    // MARK: login / logout

    func login(network: NetworkKey, hmacKey: HMACKey?, secret: Secret, pathPrefix: String) -> Error? {
        if self.isRunning {
            guard self.logout() == true else {
                return GoBotError.duringProcessing("failure during logging out previous session", GoBotError.alreadyStarted)
            }
        }
        
        self.repoPath = pathPrefix.appending("/GoSbot")
        
        // TODO: device address enumeration (v6 and v4)
        // https://github.com/VerseApp/ios/issues/82
        let listenAddr = ":8008" // can be set to :0 for testing

        let servicePubs: [Identity] = Environment.PlanetarySystem.systemPubs.map { $0.feed }

        let cfg = GoBotConfig(
            AppKey: network.string,
            HMACKey: hmacKey == nil ? "" : hmacKey!.string,
            KeyBlob: secret.jsonString()!,
            Repo: self.repoPath,
            ListenAddr: listenAddr,
            Hops: 1,
            SchemaVersion: ViewDatabase.schemaVersion,
            ServicePubs: servicePubs)
        
        let enc = JSONEncoder()
        var cfgStr: String
        do {
            let d = try enc.encode(cfg)
            cfgStr = String(data: d, encoding: .utf8)!
        } catch {
            return GoBotError.duringProcessing("config prep failed", error)
        }

        var worked = false
        cfgStr.withGoString {
            cfgGoStr in
            worked = ssbBotInit(cfgGoStr, self.notifyBlobReceived, self.notifyNewBearerToken)
        }
        
        if worked {
            self.replicate(feed: secret.identity)
            // make sure internal planetary pubs are authorized for connections
            for pub in servicePubs {
                self.replicate(feed: pub)
            }
            
            return nil
        }
        
        return GoBotError.unexpectedFault("failed to start")
    }
    
    func logout() -> Bool {
        guard self.isRunning else {
            Log.info("[GoBot] wanted to logout but bot not running")
            return false
        }
            
        if !ssbBotStop() {
            Log.fatal(.botError, "stoping GoSbot failed.")
            return false
        }
        return true
    }

    // MARK: planetary services

    // TODO: deprecated
    private lazy var notifyNewBearerToken: CPlanetaryBearerTokenCallback = { cstr, expires in
        return
    }

    // MARK: connections

    func openConnections() -> UInt {
        UInt(ssbOpenConnections())
    }
    
    // extracts the current open connections from  bot status
    func openConnectionList() -> [(String, Identity)] {
        var open: [(String, Identity)] = []
        if let status = try? self.status() {
            for p in  status.Peers {
                // split of multiserver addr format
                // ex: net:1.2.3.4:8008~shs:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=
                if !p.Addr.hasPrefix("net:") {
                    continue
                }

                let hostWithPubkey = p.Addr.dropFirst(4)
                guard let startOfPubKey = hostWithPubkey.firstIndex(of: "~") else {
                    continue
                }

                let host = hostWithPubkey[..<startOfPubKey]
                let keyB64Start = hostWithPubkey.index(startOfPubKey, offsetBy: 5) // ~shs:
                let pubkey = hostWithPubkey[keyB64Start...]

                open.append((String(host), String(pubkey)))
            }
        }
        return open
    }
    
    func disconnectAll() {
        if !ssbDisconnectAllPeers() {
            let error = GoBotError.unexpectedFault("failed to disconnect all peers")
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }

    @discardableResult
    func dial(from peers: [MultiserverAddress], atLeast: Int, tries: Int = 10) -> Bool {
        let wanted = min(peers.count, atLeast) // how many connections are we shooting for?
        var hasWorked: Int = 0
        var tried: Int = tries
        while hasWorked < wanted && tried > 0 {
            if self.dialAnyone(from: peers) {
                hasWorked += 1
            }
            tried -= 1
        }
        if hasWorked != wanted {
            Log.unexpected(.botError, "failed to make peer connection(s)")
            return false
        }
        return true
    }

    private func dialAnyone(from peers: [MultiserverAddress]) -> Bool {
        guard let peer = peers.randomElement() else {
            Log.unexpected(.botError, "no peers in sheduler table")
            return false
        }
        return self.dialOne(peer: peer)
    }
    
    @discardableResult
    func dialSomePeers(from peers: [MultiserverAddress]) -> Bool {
        guard peers.count > 0 else {
            Log.debug("User doesn't have any redeemed pubs")
            return false
        }
        
        // connect to two peers based on go-ssb's internal logic (reliability)
        let disconnectSuccess = ssbDisconnectAllPeers()
        if !disconnectSuccess {
            Log.error("Failed to disconnect peers")
        }
        
        // Also connect to two random peers
        let connectToRandom = self.dial(from: peers, atLeast: 2, tries: 10)
        if !connectToRandom {
            Log.error("Failed to connect to random peers")
        }
        
        return disconnectSuccess && connectToRandom
    }
    
    func dialOne(peer: MultiserverAddress) -> Bool {
        Log.debug("Dialing \(peer.string)")
        var worked = false
        peer.string.withGoString {
            worked = ssbConnectPeer($0)
        }
        if !worked {
            Log.unexpected(.botError, "muxrpc connect to \(peer) failed")
        }
        return worked
    }

    @discardableResult
    func dialForNotifications(from peers: [MultiserverAddress]) -> Bool {
        if let peer = peers.randomElement() {
            return dialOne(peer: peer)
        } else {
            return false
        }
    }

    // MARK: Status / repo stats

    /// Fetches some metadata about the go-ssb log including how many messages it has.
    /// This should only be called on the `serialQueue`.
    func repoStats() throws -> ScuttlegobotRepoCounts {
        guard let counts = ssbRepoStats() else {
            throw GoBotError.unexpectedFault("failed to get repo counts")
        }
        let countData = String(cString: counts).data(using: .utf8)!
        free(counts)
        let dec = JSONDecoder()
        return try dec.decode(ScuttlegobotRepoCounts.self, from: countData)
    }
    
    /// Fetches some metadata about the go-ssb log including how many messages it has.
    /// This should only be called on the `serialQueue`.
    func repoStats() -> Result<ScuttlegobotRepoCounts, Error> {
        do {
            return .success(try repoStats())
        } catch {
            return .failure(error)
        }
    }
    
    // repoFSCK returns true if the repo is fine and otherwise false
    private lazy var fsckProgressNotify: CFSCKProgressCallback = {
        percDone, remaining in
        guard let remStr = remaining else { return }
        let status = "Database consistency check in progress.\nSorry, this will take a moment.\nTime remaining: \(String(cString: remStr))"
        let notification = Notification.didUpdateFSCKRepair(perc: percDone / 100, status: status)
        NotificationCenter.default.post(notification)
    }
    
    func repoFSCK(_ mode: ScuttlegobotFSCKMode) -> Bool {
        let ret = ssbOffsetFSCK(mode.rawValue, self.fsckProgressNotify)
        return ret == 0
    }
    
    func fsckAndRepair() -> (Bool, ScuttlegobotHealReport?) {
        // disable sync during fsck check and cleanup
        // new message kill the performance of this process
        self.disconnectAll()

        // TODO: disable network listener to stop local connections
        // would be better then a polling timer but this suffices as a bug fix
        let dcTimer = RepeatingTimer(interval: 5, completion: {
            self.disconnectAll()
        })
        dcTimer.start()

        defer {
            dcTimer.stop()
        }

        NotificationCenter.default.post(Notification.didStartFSCKRepair())
        defer {
            NotificationCenter.default.post(Notification.didFinishFSCKRepair())
        }
        guard self.repoFSCK(.Sequences) == false else {
            Log.unexpected(.botError, "repair was triggered but repo fsck says it's fine")
            return (true, nil)
        }
        guard let reportData = ssbHealRepo() else {
            Log.unexpected(.botError, "repo healing failed")
            return (false, nil)
        }
        let d = String(cString: reportData).data(using: .utf8)!
        free(reportData)
        let dec = JSONDecoder()
        do {
            let report = try dec.decode(ScuttlegobotHealReport.self, from: d)
            return (true, report)
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            return (false, nil)
        }
    }
    
    func status() throws -> ScuttlegobotBotStatus {
        guard let status = ssbBotStatus() else {
            throw GoBotError.unexpectedFault("failed to get bot status")
        }
        let d = String(cString: status).data(using: .utf8)!
        free(status)
        let dec = JSONDecoder()
        return try dec.decode(ScuttlegobotBotStatus.self, from: d)
    }
    
    // MARK: manual block / replicate
    
    /// Instructs the bot to stop replicating the current feed without publishing a message on the user's log.
    func ban(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedBlock($0, true)
        }
    }
    
    /// Instructs the bot to start replicating the given feed again if appropriate, undoing a call to `ban(feed:)`.
    func unban(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedBlock($0, false)
        }
    }

    func unblock(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedBlock($0, false)
        }
    }

    // TODO: call this to fetch a feed without following it
    func replicate(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedReplicate($0, true)
        }
    }

    func dontReplicate(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedReplicate($0, false)
        }
    }

    // MARK: Null / Delete

    func nullContent(author: Identity, sequence: UInt) throws {
        guard author.algorithm == .ggfeed else {
            throw GoBotError.unexpectedFault("unsupported feed format for deletion")
        }
        
        var err: Error?
        author.withGoString {
            goAuthor in
            guard ssbNullContent(goAuthor, UInt64(sequence)) == 0 else {
                err = GoBotError.unexpectedFault("gobot: null content failed")
                return
            }
        }
        
        if let e = err {
            throw e
        }
    }
    
    func nullFeed(author: Identity) throws {
        var err: Error?
        author.withGoString {
            goAuthor in
            guard ssbNullFeed(goAuthor) == 0 else {
                err = GoBotError.unexpectedFault("gobot: null feed failed")
                return
            }
        }
        if let e = err {
            throw e
        }
    }

    // MARK: blobs

    private lazy var notifyBlobReceived: CBlobsNotifyCallback = {
        _, ref in
        guard let ref = ref else { return false }
        let identifier = BlobIdentifier(cString: ref)
        let notification = Notification.didLoadBlob(identifier)
        NotificationCenter.default.post(notification)
        return true
    }

    func blobsAdd(data: Data, completion: @escaping BlobsAddCompletion) {
        /// Apple docs say to interact with pipe on the main thread (or one configured with a run loop)
        let pipe = Pipe()

        // Start writing the file
        DispatchQueue.main.async {
            pipe.fileHandleForWriting.write(data)
            pipe.fileHandleForWriting.closeFile()
        }
        
        // Give go-ssb the file handle to read
        let readFD = pipe.fileHandleForReading.fileDescriptor
        guard let rawBytes = ssbBlobsAdd(readFD) else {
            completion("", GoBotError.unexpectedFault("blobsAdd failed"))
            return
        }
        
        let newRef = String(cString: rawBytes)
        free(rawBytes)
        completion(newRef, nil)
    }
    
    func blobFileURL(ref: BlobIdentifier) throws -> URL {
        let hexRef = ref.hexEncodedString()
        if hexRef.isEmpty {
            throw GoBotError.unexpectedFault("blobGet: could not make hex representation of blob reference")
        }
         // first 2 chars are directory
        let dir = String(hexRef.prefix(2))
        // rest ist filename
        let restIdx = hexRef.index(hexRef.startIndex, offsetBy: 2)
        let rest = String(hexRef[restIdx...])

        var u = URL(fileURLWithPath: self.repoPath)
        u.appendPathComponent("blobs")
        u.appendPathComponent("sha256")
        u.appendPathComponent(dir)
        u.appendPathComponent(rest)
       
        return u
    }

    /// Tries to fetch a blob from the filesystem. If the blob cannot be found, we indicate to go-ssb that we want
    /// it to download the blob from a peer.
    func blobGet(ref: BlobIdentifier) throws -> Data {
        let u = try blobFileURL(ref: ref)
        do {
            return try Data(contentsOf: u)
        } catch {
            do {
                try blobsWant(ref: ref)
                throw BotError.blobUnavailable
            } catch {
                throw error
            }
        }
    }
    
    func blobsWant(ref: BlobIdentifier) throws {
        var worked = false
        ref.withGoString {
            worked = ssbBlobsWant($0)
        }
        if !worked {
            throw GoBotError.unexpectedFault("BlobsWant failed")
        }
    }
    
    // retreive a list of stored feeds and their current sequence number
    func getFeedList(completion: @escaping (([Identity: Int], Error?) -> Void)) {
        var err: Error?
        var feeds = [Identity: Int]()
        defer {
            completion(feeds, err)
        }
        
        let intfd = ssbReplicateUpTo()
        if intfd == -1 {
            err = GoBotError.unexpectedFault("feedList pre-processing error")
            return
        }
        let file = FileHandle(fileDescriptor: intfd, closeOnDealloc: true)
        let fld = file.readDataToEndOfFile()
    
        /* form of the response is
              {
                  "feed1": currSeqAsInt,
                  "feed2": currSeqAsInt,
                  "feed3": currSeqAsInt
              }
        */
       
        do {
            let json = try JSONSerialization.jsonObject(with: fld, options: [])
            if let dictionary = json as? [String: Any] {
                for (feed, val) in dictionary {
                    feeds[feed] = val as? Int
                }
            }
        } catch {
            err = GoBotError.duringProcessing("feedList json decoding error:", error)
            return
        }
    }
    
    // MARK: message streams
    
    /// This fetches posts from go-ssb's RootLog - the log containing all posts from all users. The Go code will filter
    /// out some messages, such as those from blocked users and old messages.
    func getReceiveLog(startSeq: UInt64, limit: Int32) throws -> Messages {
        guard let rawBytes = ssbStreamRootLog(startSeq, limit) else {
            throw GoBotError.unexpectedFault("rxLog pre-processing error")
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Message].self, from: data)
        } catch {
            throw GoBotError.duringProcessing("rxLog json decoding error:", error)
        }
    }
    
    /// Fetches all the posts that the current user has published after the post with sequence number `startSeq`.
    func getPublishedLog(after index: Int64) throws -> Messages {
        guard let rawBytes = ssbStreamPublishedLog(index) else {
            throw GoBotError.unexpectedFault("publishedLog pre-processing error")
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([Message].self, from: data)
        } catch {
            throw GoBotError.duringProcessing("publishedLog json decoding error:", error)
        }
    }
    
    // aka private.read
    func getPrivateLog(startSeq: Int64, limit: Int) throws -> Messages {
        guard let rawBytes = ssbStreamPrivateLog(UInt64(startSeq), Int32(limit)) else {
            throw GoBotError.unexpectedFault("privateLog pre-processing error")
        }
        
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([Message].self, from: data)
        } catch {
            throw GoBotError.duringProcessing("privateLog json decoding error:", error)
        }
    }
    
    // MARK: Publish
    
    /// Publishes the given content to the logged-in user's feed.
    /// Note: make sure to sync the user's feed from the go-ssb log to the ViewDatabase after calling this.
    func publish(_ content: ContentCodable, completion: @escaping PublishCompletion) {
        var contentStr: String = ""
        do {
             let cData = try content.encodeToData()
            contentStr = String(data: cData, encoding: .utf8) ?? "]},invalid]-warning:invalid content"
        } catch {
            let err = GoBotError.duringProcessing("publish: failed to write content", error)
            completion("", err)
        }

        contentStr.withGoString {
            guard let cRef = ssbPublish($0) else {
                completion("", GoBotError.unexpectedFault("publish failed"))
                return
            }
            let newRef = String(cString: cRef)
            free(cRef)
            completion(newRef, nil)
        }
    }
    
    // MARK: Aliases
    
    func register(alias: String, in room: Room) throws -> String {
        Log.debug("Registering room alias: \(alias) at \(room.address.string)")
        let result: ssbRoomsAliasRegisterReturn_t = room.address.string.withGoString { roomAddress in
            alias.withGoString { alias in
                ssbRoomsAliasRegister(roomAddress, alias)
            }
        }
        
        if result.alias != nil {
            let aliasURLString = String(cString: result.alias)
            if aliasURLString.isEmpty == false {
                return aliasURLString
            }
        }
        
        switch result.err {
        case 2:
            throw RoomRegistrationError.aliasTaken
        case 1:
            fallthrough
        default:
            throw RoomRegistrationError.unknownError
        }
    }
    
    func revoke(alias: RoomAlias) async throws {
        
    }
}
