//
//  Star.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

struct Star {
    let invite: String
    
    private(set) var feed: Identifier
    private(set) var host: String
    private(set) var port: UInt
    
    var tcpAddress: String {
        return "\(host):\(port)"
    }
    
    init(invite: String) {
        self.invite = invite
        
        // Parse Feed Identity and TCP Addreess out of the invite
        let range = NSRange(location: 0, length: invite.utf16.count)
        let regex = try! NSRegularExpression(pattern: "(.*):([0-9]*):(.*)~.*")
        let match = regex.firstMatch(in: invite, options: [], range: range)!
        let hostRange = Range(match.range(at: 1), in: invite)!
        self.host = String(invite[hostRange])
        let portRange = Range(match.range(at: 2), in: invite)!
        self.port = UInt(invite[portRange])!
        let feedRange = Range(match.range(at: 3), in: invite)!
        self.feed = String(invite[feedRange])
    }
    
    func toPeer() -> Peer {
        return Peer(tcpAddr: self.tcpAddress, pubKey: self.feed)
    }
    
    func toPub() -> Pub {
        let address = PubAddress(key: self.feed, host: self.host, port: self.port)
        return Pub(type: .pub, address: address)
    }
}

extension Star: Hashable {
    
    func hash(into hasher: inout Hasher) {
        self.feed.hash(into: &hasher)
    }
    
}
