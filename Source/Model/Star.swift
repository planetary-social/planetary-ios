//
//  Star.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger
import Network

/// An object representing a Planetary owned SSB pub server, including connection information and an embedded
/// invitation. AKA system pubs.
struct Star {
    let invite: String
    
    private(set) var feed: Identifier
    private(set) var host: String
    private(set) var port: UInt
    
    var tcpAddress: String {
        "\(host):\(port)"
    }
    
    var address: PubAddress {
        PubAddress(key: self.feed, host: self.host, port: self.port)
    }
    
    init(invite: String) {
        self.invite = invite
        
        // Parse Feed Identity and TCP Addreess out of the invite
        let range = NSRange(location: 0, length: invite.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: "(.*):([0-9]*):(.*)~.*") else {
            self.host = ""
            self.port = 0
            self.feed = Identifier.null
            return
        }
        
        let match = regex.firstMatch(in: invite, options: [], range: range)!
        let hostRange = Range(match.range(at: 1), in: invite)!
        self.host = String(invite[hostRange])
        let portRange = Range(match.range(at: 2), in: invite)!
        self.port = UInt(invite[portRange])!
        let feedRange = Range(match.range(at: 3), in: invite)!
        self.feed = String(invite[feedRange])
    }
    
    static func isValid(invite: String) -> Bool {
        let range = NSRange(location: 0, length: invite.utf16.count)
        guard let regex = try? NSRegularExpression(pattern: "(.*):([0-9]*):(.*)~.*") else {
            return false
        }
        return regex.numberOfMatches(in: invite, options: [], range: range) > 0
    }
    
    func toPeer() -> Peer {
        Peer(tcpAddr: self.tcpAddress, pubKey: self.feed)
    }
    
    func toPub() -> Pub {
        Pub(type: .pub, address: self.address)
    }
    
    /// Checks whether we can establish a TCP connection to the star. This is only necessary to work around a bug
    /// in go-ssb and can probably go away after #301 is solved.
    func testConnection(completion: @escaping (Bool) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(false)
            return
        }
        
        let tcpConnection = NWConnection(host: NWEndpoint.Host(host), port: port, using: NWParameters.tcp)
        tcpConnection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                completion(true)
                tcpConnection.cancel()
            case .setup, .preparing, .cancelled:
                return
            case .failed(let error), .waiting(let error):
                Log.optional(error)
                completion(false)
                tcpConnection.cancel()
            @unknown default:
                completion(true)
                tcpConnection.cancel()
            }
        }
        tcpConnection.start(queue: DispatchQueue.global(qos: .utility))
    }
}

extension Star: Hashable {
    
    func hash(into hasher: inout Hasher) {
        self.feed.hash(into: &hasher)
    }
}
