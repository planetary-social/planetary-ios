//
//  GoBot.swift
//  FBTT
//
//  Created by Henry Bubert on 22.01.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import UIKit


// get's called with the size and the hash (might return a bool just as a demo of passing data back)
typealias CBlobsNotifyCallback = @convention(c) (Int64, UnsafePointer<Int8>?) -> Bool

// get's called with the messages left to process
typealias CFSCKProgressCallback = @convention(c) (Float64, UnsafePointer<Int8>?) -> Void

enum GoBotError: Error {
    case alreadyStarted
    case duringProcessing(String, Error)
    case unexpectedFault(String)
}

struct Peer {
    let tcpAddr: String
    let pubKey: Identity
}

// used to drain a single user feed
fileprivate struct FeedLogRequest: Codable {
    let feed: Identity
    let sequence: Int
    let limit: Int
    let keys: Bool
}

struct ScuttlegobotRepoCounts: Decodable {
    let messages: UInt
    let feeds: UInt
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
    case FeedLength = 0 // TODO: wasn't sure if they start from 0 by default

    // goes through all the messages and makes sure the sequences increament correctly for each feed
    case Sequences = 1
}

struct ScuttlegobotHealReport: Decodable {
    let Authors: [Identity]
    let Messages: UInt32
}

fileprivate struct BotConfig: Encodable {
    let AppKey: String
    let HMACKey: String
    let KeyBlob: String
    let Repo: String
    let ListenAddr: String
    let Hops: UInt
    let SchemaVersion: UInt
    #if DEBUG
    let Testing: Bool = true
    #else
    let Testing: Bool = false
    #endif
    
}

class GoBotInternal {

    var currentRepoPath: String { return self.repoPath }
    private var repoPath: String = "/tmp/FBTT/unset"
    
    // TODO this is little dangerous if Identities.verse is modified
    // ultimately this should be configured from querying
    // the Verse REST API
    // tuple of primary and fallbacks TODO: undo this once the live-streaming is in place
    private var allPeers: [ String : (Peer, [Peer]) ] = [
        NetworkKey.ssb.string: ( Peer(tcpAddr: "main2.planetary.social:8008", pubKey: Identities.ssb.pubs["planetary-pub2"]!) , [
            Peer(tcpAddr: "main1.planetary.social:8008", pubKey: Identities.ssb.pubs["planetary-pub1"]!),
            Peer(tcpAddr: "main3.planetary.social:8008", pubKey: Identities.ssb.pubs["planetary-pub3"]!),
            Peer(tcpAddr: "main4.planetary.social:8008", pubKey: Identities.ssb.pubs["planetary-pub4"]!)
        ]),

        NetworkKey.planetary.string: (Peer(tcpAddr: "demo2.planetary.social:7227", pubKey: Identities.planetary.pubs["testpub_go2"]!), [
            Peer(tcpAddr: "demo1.planetary.social:8008", pubKey: Identities.planetary.pubs["testpub_go1"]!),
            Peer(tcpAddr: "demo3.planetary.social:8008", pubKey: Identities.planetary.pubs["testpub_go3"]!),
            Peer(tcpAddr: "demo4.planetary.social:8008", pubKey: Identities.planetary.pubs["testpub_go4"]!),

            Peer(tcpAddr: "demo5.planetary.social:8008", pubKey: Identities.planetary.pubs["testpub_go_testing1"]!),
            Peer(tcpAddr: "demo6.planetary.social:8008", pubKey: Identities.planetary.pubs["testpub_go_testing2"]!)
        ]),

        NetworkKey.integrationTests.string: (Peer(tcpAddr: "testing-ci.planetary.social:9119", pubKey: Identities.testNet.pubs["integrationpub1"]!), [])
    ]
    
    private var peers: [Peer] {
        get {
            guard let peersForNetwork = self.allPeers[self.currentNetwork.string] else {
                return []
            }
            var peersList: [Peer] = []
            peersList.append(peersForNetwork.0)
            for p in peersForNetwork.1 {
                peersList.append(p)
            }
            return peersList
        }
    }

    var peerIdentities: [(String, String)] {
        var identities: [(String, String)] = []
        for peer in self.peers { identities += [(peer.tcpAddr, peer.pubKey)] }
        return identities
    }

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

    func isRunning() -> Bool {
        return ssbBotIsRunning()
    }

    private var currentNetwork: NetworkKey = NetworkKey.ssb

    var getNetworkKey: NetworkKey {
        return self.currentNetwork
    }

    // MARK: login / logout

    func login(network: NetworkKey, hmacKey: HMACKey?, secret: Secret, pathPrefix: String) -> Error? {
        if self.isRunning() {
            return GoBotError.alreadyStarted
        }
        
        self.repoPath = pathPrefix.appending("/GoSbot")
        
        // TODO: device address enumeration (v6 and v4)
        // https://github.com/VerseApp/ios/issues/82UInt
        let listenAddr = ":8008" // can be set to :0 for testing

        let cfg = BotConfig(
            AppKey: network.string,
            HMACKey: hmacKey == nil ? "" : hmacKey!.string,
            KeyBlob: secret.jsonString()!,
            Repo: self.repoPath,
            ListenAddr: listenAddr,
            Hops: 1,
            SchemaVersion: ViewDatabase.schemaVersion)
        
        let enc = JSONEncoder()
        var cfgStr: String
        do {
            let d = try enc.encode(cfg)
            cfgStr = String(data: d, encoding: .utf8)!
        } catch {
            return GoBotError.duringProcessing("config prep failed", error)
        }

        var worked: Bool = false
        cfgStr.withGoString {
            cfgGoStr in
            worked = ssbBotInit(cfgGoStr, self.blobsNotify)
        }
        
        if worked {
            self.currentNetwork = network
            return nil
        }
        
        return GoBotError.unexpectedFault("failed to start")
    }
    
    func logout() {
        guard self.isRunning() else {
            Log.info("[GoBot] wanted to logout but bot not running")
            return
        }
            
        if !ssbBotStop() {
            Log.fatal(.botError, "stoping GoSbot failed.")
            return
        }
    }

    // MARK: connections

    func openConnections() -> UInt {
        return UInt(ssbOpenConnections())
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
        if !ssbDisconnectAllPeers(){
            let error = GoBotError.unexpectedFault("failed to disconnect all peers")
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }

    @discardableResult
    func dial(atLeast: Int, tries: Int = 10) -> Bool {
        let wanted = min(self.peers.count, atLeast) // how many connections are we shooting for?
        var hasWorked :Int = 0
        var tried: Int = tries
        while hasWorked < wanted && tried > 0 {
            if self.dialAnyone() {
                hasWorked += 1
            }
            tried -= 1
        }
        if hasWorked != wanted {
            Log.unexpected(.botError, "failed to make pub connection(s)")
            return false
        }
        return true
    }

    private func dialAnyone() -> Bool {
        guard let p = self.peers.randomElement() else {
            Log.unexpected(.botError, "no peers in sheduler table")
            return false
        }
        return self.dialOne(peer: p)
    }
    
    @discardableResult
    func dialSomePeers() -> Bool {
        guard self.openConnections() == 0 else { return true } // only make connections if we dont have any
        ssbConnectPeers(3)
        self.dial(atLeast: 2, tries: 10)
        return true
    }
    
    func dialOne(peer: Peer) -> Bool {
        let multiServ = "net:\(peer.tcpAddr)~shs:\(peer.pubKey.id)"
        var worked: Bool = false
        multiServ.withGoString {
            worked = ssbConnectPeer($0)
        }
        if !worked {
            Log.unexpected(.botError, "muxrpc connect to \(peer) failed")
        }
        return worked
    }

    @discardableResult
    func dialForNotifications() -> Bool {
        guard let peersForNetwork = self.allPeers[self.currentNetwork.string] else {
            return false
        }
        return dialOne(peer: peersForNetwork.0)
    }

    // MARK: Status / repo stats

    func repoStatus() throws -> ScuttlegobotRepoCounts {
        guard let counts = ssbRepoStats() else {
            throw GoBotError.unexpectedFault("failed to get repo counts")
        }
        let countData = String(cString: counts).data(using: .utf8)!
        free(counts)
        let dec = JSONDecoder()
        return try dec.decode(ScuttlegobotRepoCounts.self, from: countData)
    }
    
    // repoFSCK returns true if the repo is fine and otherwise false
    private lazy var fsckProgressNotify: CFSCKProgressCallback = {
        percDone, remaining in
        guard let remStr = remaining else { return }
        let status = "Database consistency check in progress.\nSorry, this will take a moment.\nTime remaining: \(String(cString: remStr))"
        let notification = Notification.didUpdateDatabaseProgress(perc: percDone/100, status: status)
        NotificationCenter.default.post(notification)
    }
    
    func repoFSCK(_ mode: ScuttlegobotFSCKMode) -> Bool {
        let ret = ssbOffsetFSCK(mode.rawValue, self.fsckProgressNotify)
        return ret == 0
    }
    
    func fsckAndRepair() -> (Bool, ScuttlegobotHealReport?) {
        NotificationCenter.default.post(Notification.didStartFSCKRepair())
        defer {
            NotificationCenter.default.post(name: .didFinishDatabaseProcessing, object: nil)
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

    private lazy var blobsNotify: CBlobsNotifyCallback = {
        numberOfBytes, ref in
        guard let ref = ref else { return false }
        let identifier = BlobIdentifier(cString: ref)
        let notification = Notification.didLoadBlob(identifier)
        NotificationCenter.default.post(notification)
        return true
    }

    func blobsAdd(data: Data, completion: @escaping BlobsAddCompletion) {
        let p = Pipe()

        self.queue.async {
            p.fileHandleForWriting.write(data)
            p.fileHandleForWriting.closeFile()
        }

        let readFD = p.fileHandleForReading.fileDescriptor
        guard let rawBytes = ssbBlobsAdd(readFD) else {
            completion("", GoBotError.unexpectedFault("blobsAdd failed"))
            return
        }
        
        let newRef = String(cString: rawBytes)
        free(rawBytes)
        completion(newRef, nil)
    }

    func blobGet(ref: BlobIdentifier) throws -> Data {
        let hexRef = ref.hexEncodedString()
        if hexRef.isEmpty {
            throw GoBotError.unexpectedFault("blobGet: could not make hex representation of blob reference")
        }
         // first 2 chars are directory
        let dir = String(hexRef.prefix(2))
        // rest ist filename
        let restIdx = hexRef.index(hexRef.startIndex, offsetBy:2)
        let rest = String(hexRef[restIdx...])

        var u = URL(fileURLWithPath: self.repoPath)
        u.appendPathComponent("blobs")
        u.appendPathComponent("sha256")
        u.appendPathComponent(dir)
        u.appendPathComponent(rest)
        
        do {
            let data = try Data(contentsOf: u)
            return data
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
        var worked: Bool = false
        ref.withGoString {
            worked = ssbBlobsWant($0)
        }
        if !worked {
            throw GoBotError.unexpectedFault("BlobsWant failed")
        }
    }
    
    // retreive a list of stored feeds and their current sequence number
    func getFeedList(completion: @escaping (([Identity : Int], Error?)->Void)) {
        var err: Error? = nil
        var feeds = [Identity : Int]()
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
    
    
    // aka createUserStream
    func getMessagesForFeed(feed: String, startSeq: Int, limit: Int, completion: @escaping FeedCompletion) {
        completion([], GoBotError.unexpectedFault("getMessagesForFeed: deperecated - use viewDB"))
    }
    
    // aka createLogStream
    func getReceiveLog(startSeq: Int64, limit: Int, completion: @escaping FeedCompletion) {
        var err: Error? = nil
        var msgs = [KeyValue]()
        defer {
            completion(msgs, err)
        }

        guard let rawBytes = ssbStreamRootLog(UInt64(startSeq), Int32(limit)) else {
            err = GoBotError.unexpectedFault("rxLog pre-processing error")
            return
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        do {
            let decoder = JSONDecoder()
            msgs = try decoder.decode([KeyValue].self, from: data)
        } catch {
            err = GoBotError.duringProcessing("rxLog json decoding error:", error)
            return
        }
    }
    
    // aka private.read
    func getPrivateLog(startSeq: Int64, limit: Int, completion: @escaping FeedCompletion) {
        var err: Error? = nil
        var msgs = [KeyValue]()
        defer {
            completion(msgs, err)
        }

        guard let rawBytes = ssbStreamPrivateLog(UInt64(startSeq), Int32(limit)) else {
            err = GoBotError.unexpectedFault("privateLog pre-processing error")
            return
        }
        let data = String(cString: rawBytes).data(using: .utf8)!
        free(rawBytes)
        let decoder = JSONDecoder()
        do {
            msgs = try decoder.decode([KeyValue].self, from: data)
        } catch {
            err = GoBotError.duringProcessing("privateLog json decoding error:", error)
            return
        }
    }
    
    // MARK: Publish
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
}
