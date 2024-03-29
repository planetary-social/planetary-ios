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
}

// these structs are set this way to match the Go code
// swiftlint:disable identifier_name

struct ScuttlegobotPeerStatus: Decodable {
    let publicKey: String
    let address: String
}

struct ScuttlegobotBotStatus: Decodable {
    let peers: [ScuttlegobotPeerStatus]
}

private struct GoBotConfig: Encodable {
    let networkKey: String
    let hmacKey: String
    let keyBlob: String
    let repo: String
    let oldRepo: String
    let listenAddr: String
    let hops: UInt
    let testing: Bool
    
    func stringRepresentation() throws -> String {
        let configData = try JSONEncoder().encode(self)
        if let string = String(data: configData, encoding: .utf8) {
            return string
        } else {
            throw GoBotError.unexpectedFault("Could not encode config to string")
        }
    }
}

// swiftlint:enable identifier_name

class GoBotInternal {

    var currentRepoPath: String { self.repoPath }
    private var repoPath: String = "/tmp/FBTT/unset"
    private var oldRepoPath: String = "/tmp/FBTT/unset"
    
    let name = "GoBot"
    let version = "project-raptor"

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

    func login(
        network: NetworkKey,
        hmacKey: HMACKey?,
        secret: Secret,
        pathPrefix: String,
        migrationDelegate: BotMigrationDelegate
    ) async throws {
        if self.isRunning {
            guard self.logout() == true else {
                throw GoBotError.duringProcessing("failure during logging out previous session", GoBotError.alreadyStarted)
            }
        }
        
        self.oldRepoPath = pathPrefix.appending("/GoSbot")
        self.repoPath = pathPrefix.appending("/scuttlego")
        
        // TODO: device address enumeration (v6 and v4)
        // https://github.com/VerseApp/ios/issues/82
        let listenAddr = ":8008" // can be set to :0 for testing

        let servicePubs: [Identity] = Environment.PlanetarySystem.systemPubs.map { $0.feed }

        let config = GoBotConfig(
            networkKey: network.string,
            hmacKey: hmacKey == nil ? "" : hmacKey!.string,
            keyBlob: secret.jsonString()!,
            repo: self.repoPath,
            oldRepo: self.oldRepoPath,
            listenAddr: listenAddr,
            hops: 2,
            testing: false
        )
        
        var configString: String
        do {
            configString = try config.stringRepresentation()
        } catch {
            throw GoBotError.duringProcessing("config prep failed", error)
        }
        
        // Run the actual call to ssbBotInit in a detached task and withCheckedThrowingContinuation.
        // Both are necessary to yield the calling thread.
        try await Task.detached { [migrationDelegate, configString] in
            try await withCheckedThrowingContinuation { continuation in
                var worked = false
                configString.withGoString { configGoString in
                    worked = ssbBotInit(
                        configGoString,
                        self.notifyBlobReceived,
                        migrationDelegate.onRunningCallback,
                        migrationDelegate.onErrorCallback,
                        migrationDelegate.onDoneCallback
                    )
                }
                
                if worked {
                    self.replicate(feed: secret.identity)

                    for pub in servicePubs {
                        self.replicate(feed: pub)
                    }
                    
                    continuation.resume()
                } else {
                    continuation.resume(throwing: GoBotError.unexpectedFault("failed to start"))
                }
            }
        }.value
    }

    @discardableResult
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
    private lazy var notifyNewBearerToken: CPlanetaryBearerTokenCallback = { _, _ in
        }

    // MARK: connections

    func openConnections() -> UInt {
        UInt(ssbOpenConnections())
    }
    
    // extracts the current open connections from  bot status
    func openConnectionList() -> [(String, Identity)] {
        var open: [(String, Identity)] = []
        if let status = try? self.status() {
            for p in  status.peers {
                open.append((String(p.address), String(p.publicKey)))
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
    
    func status() throws -> ScuttlegobotBotStatus {
        guard let status = ssbBotStatus() else {
            throw GoBotError.unexpectedFault("failed to get bot status")
        }
        let d = String(cString: status).data(using: .utf8)!
        free(status)
        let dec = JSONDecoder()
        return try dec.decode(ScuttlegobotBotStatus.self, from: d)
    }
        
    func setBanList(banList: BanList) throws {
        let encodedHashes = try JSONEncoder().encode(banList)
        let hashesStr = String(data: encodedHashes, encoding: .utf8)!
        let succeeded = hashesStr.withGoString {
            return ssbBanListSet($0)
        }
        if !succeeded {
            throw GoBotError.unexpectedFault("failed to set the ban list")
        }
    }

    // TODO: call this to fetch a feed without following it
    func replicate(feed: FeedIdentifier) {
        feed.withGoString {
            ssbFeedReplicate($0)
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

        var u = URL(fileURLWithPath: self.oldRepoPath)
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
    
    // MARK: message streams
    
    /// This fetches posts from go-ssb's RootLog - the log containing all posts from all users. The Go code will filter
    /// out some messages, such as those from blocked users and old messages.
    func getReceiveLog(startSeq: UInt64, limit: Int32) throws -> [ReceiveLogMessage] {
        guard let rawBytes = ssbStreamRootLog(startSeq, limit) else {
            throw GoBotError.unexpectedFault("rxLog pre-processing error")
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ReceiveLogMessage].self, from: data)
        } catch {
            throw GoBotError.duringProcessing("rxLog json decoding error:", error)
        }
    }
    
    /// Fetches all the posts that the current user has published after the post with sequence number `startSeq`.
    func getPublishedLog(after index: Int64) throws -> [ReceiveLogMessage] {
        guard let rawBytes = ssbStreamPublishedLog(index) else {
            throw GoBotError.unexpectedFault("publishedLog pre-processing error")
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([ReceiveLogMessage].self, from: data)
        } catch {
            throw GoBotError.duringProcessing("publishedLog json decoding error:", error)
        }
    }
    
    // aka private.read
    func getPrivateLog(startSeq: Int64, limit: Int) throws -> [ReceiveLogMessage] {
        guard let rawBytes = ssbStreamPrivateLog(UInt64(startSeq), Int32(limit)) else {
            throw GoBotError.unexpectedFault("privateLog pre-processing error")
        }
        
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode([ReceiveLogMessage].self, from: data)
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
        default:
            throw RoomRegistrationError.unknownError
        }
    }
    
    func revoke(alias: RoomAlias) async throws {
    }
}
