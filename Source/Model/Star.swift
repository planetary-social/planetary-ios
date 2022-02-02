//
//  Star.swift
//  Planetary
//
//  Created by Martin Dutra on 8/11/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation
import Network

func createTLSParameters(allowInsecure: Bool, queue: DispatchQueue) -> NWParameters {
    let options = NWProtocolTLS.Options()
    sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
        let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            sec_protocol_verify_complete(true)
        } else {
            if allowInsecure == true {
                sec_protocol_verify_complete(true)
            } else {
                sec_protocol_verify_complete(false)
            }
        }
    }, queue)
    return NWParameters(tls: options)
}

struct Star {
    let invite: String
    
    private(set) var feed: Identifier
    private(set) var host: String
    private(set) var port: UInt
    
    var tcpAddress: String {
        return "\(host):\(port)"
    }
    
    var address: PubAddress {
        return PubAddress(key: self.feed, host: self.host, port: self.port)
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
        return Peer(tcpAddr: self.tcpAddress, pubKey: self.feed)
    }
    
    func toPub() -> Pub {
        return Pub(type: .pub, address: self.address)
    }
    
    /// Checks whether we can establish a TCP connection to the star. This is only necessary to work around a bug
    /// in go-ssb and can probably go away after #301 is solved.
    func testConnection(completion: @escaping (Bool) -> Void) {
        guard let port = NWEndpoint.Port(rawValue: UInt16(port)) else {
            completion(false)
            return
        }
        
        let tcpConnection = NWConnection(host: NWEndpoint.Host(host), port: port, using: createTLSParameters(allowInsecure: true, queue: DispatchQueue(label: "verifyQueue")))
        tcpConnection.stateUpdateHandler = { state in
            print(state)
            switch state {
            case .ready:
                completion(true)
                tcpConnection.cancel()
            case .setup, .preparing, .cancelled:
                return
            case .failed, .waiting:
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
