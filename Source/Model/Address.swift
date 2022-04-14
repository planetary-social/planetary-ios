//
//  Address.swift
//  FBTT
//
//  Created by Henry Bubert on 02.04.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import Logger

// new pub/peer advertisments
// address is multiserver encoded like net:10.10.0.1:8008~shs:pybKey=
// but only go bot has to deal with that.
// just using sqlite the datastore for enable/worked
struct Address: Codable {
    let type: ContentType
    let address: String
    let availability: Double
}

struct Pub: ContentCodable {
    let type: ContentType
    let address: MultiserverAddress
    
    func toPeer() -> Peer {
        Peer(multiserver: address)
    }
}

/// Represents a [multiserver address](https://github.com/ssb-js/multiserver).
/// Currently only supports net (TCP) and shs protocols
struct MultiserverAddress: Codable, Hashable {
    
    let rawValue: String
    let key: PublicKey
    let host: String
    let port: UInt
    
    internal init(key: PublicKey, host: String, port: UInt) {
        self.key = key
        self.host = host
        self.port = port
        self.rawValue = "net:\(host):\(port)~shs:\(key)"
    }
    
    /// Parses a multiserver address string like "net:wx.larpa.net:8008~shs:DTNmX+4SjsgZ7xyDh5xxmNtFqa6pWi5Qtw7cE8aR9TQ="
    /// only supports net (TCP) and shs protocols
    init?(string: String) {
        var address: MultiserverAddress?
        let pattern = #"net:([0-9.]+):([0-9]+)~shs:(.*)$"#
        do {
            let nsregex = try NSRegularExpression(pattern: pattern, options: [])
            let nsrange = NSRange(string.startIndex..<string.endIndex, in: string)
            nsregex.enumerateMatches(
                in: string,
                options: [],
                range: nsrange
            ) { (match, _, stop) in
                
                guard let match = match else { return }
                
                if match.numberOfRanges == 4,
                   let hostRange = Range(match.range(at: 1), in: string),
                   let portRange = Range(match.range(at: 2), in: string),
                   let keyRange  = Range(match.range(at: 3), in: string),
                   let port = UInt(string[portRange]) {
                    
                    let host = String(string[hostRange])
                    let key = String(string[keyRange])
                    address = MultiserverAddress(key: key, host: host, port: port)
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
