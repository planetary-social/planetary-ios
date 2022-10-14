//
//  Address.swift
//  FBTT
//
//  Created by Henry Bubert on 02.04.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

/// A model for the new style pub/peer advertisement messages.
/// Replaces the old 'pub' message type (`Pub` in Planetary code.
///
/// https://github.com/ssbc/ssb-device-address
struct Address: ContentCodable {
    
    let type: ContentType
    
    /// Address in multiserver format (see `MultiserverAddress`)
    let address: String
    
    let availability: Double
    
    var multiserver: MultiserverAddress? {
        MultiserverAddress(string: address)
    }
}

/// A message type that announces the location of a pub.
struct Pub: ContentCodable {
    let type: ContentType
    let address: PubAddress
    
    func toPeer() -> Peer {
        address.peer
    }
}

/// A subtype of `Pub`, encodes the IP address or domain name of a pub. Note that the `key` parameter here is a full
/// Identity string including sigil and feed format (unlike `MultiserverAddress`).
struct PubAddress: Codable, Hashable {
    
    /// The pub's identity
    let key: Identity
    
    /// The location of the pub server. An IP address or DNS name.
    let host: String
    
    /// The port to user when talking to the pub server.
    let port: UInt
    
    /// This address in multiserver format.
    var multiserver: MultiserverAddress {
        MultiserverAddress(keyID: key.id, host: host, port: port)
    }
    
    /// This address as a peer
    var peer: Peer {
        Peer(tcpAddr: "\(host):\(port)", pubKey: key)
    }
}

/// Represents a [multiserver address](https://github.com/ssbc/multiserver), pointing to another scuttlebutt peer that
/// we can talk to.
///
/// Currently this model only supports net (TCP) and shs protocols, although in general the multiserver address format
/// supports other ways of connecting.
struct MultiserverAddress: Codable, Hashable, Equatable {
    
    /// The key part of the peer's identifier. Note: this does not include the sigil or feed format identifier.
    let keyID: KeyID
    
    /// The location of the pub server. An IP address or DNS name.
    let host: String
    
    /// The port to user when talking to the peer.
    let port: UInt
    
    /// The string representation of this address.
    var string: String {
        "net:\(host):\(port)~shs:\(keyID)"
    }
    
    internal init(keyID: KeyID, host: String, port: UInt) {
        self.keyID = keyID
        self.host = host
        self.port = port
    }
    
    /// Parses a multiserver address string like
    /// "net:wx.larpa.net:8008~shs:DTNmX+4SjsgZ7xyDh5xxmNtFqa6pWi5Qtw7cE8aR9TQ=". Only supports net (TCP) and shs
    /// protocols currently.
    init?(string: String) {
        var address: MultiserverAddress?
        let pattern = #"net:([a-zA-Z\u00C0-\u024F\d\.-]+):([0-9]+)~shs:(.*)$"#
        do {
            let nsregex = try NSRegularExpression(pattern: pattern, options: [])
            let nsrange = NSRange(string.startIndex..<string.endIndex, in: string)
            nsregex.enumerateMatches(
                in: string,
                options: [],
                range: nsrange
            ) { (match, _, _) in
                
                guard let match = match else { return }
                
                if match.numberOfRanges == 4,
                    let hostRange = Range(match.range(at: 1), in: string),
                    let portRange = Range(match.range(at: 2), in: string),
                    let keyRange  = Range(match.range(at: 3), in: string),
                    let port = UInt(string[portRange]) {
                    
                    let host = String(string[hostRange])
                    let keyID = String(string[keyRange])
                    address = MultiserverAddress(keyID: keyID, host: host, port: port)
                }
            }
        } catch {
            Log.optional(error)
            return nil
        }
        
        if let address = address {
            self = address
        } else {
            return nil
        }
    }
}

struct KnownPub: Hashable {
    let AddressID: Int64

    let ForFeed: Identifier
    let Address: String // multiserver

    let InUse: Bool
    let WorkedLast: String
    let LastError: String
    let redeemed: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.AddressID)
    }
}

typealias KnownPubs = [KnownPub]
