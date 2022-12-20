//
//  Root.swift
//  FBTT
//
//  Created by Christoph on 2/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// An SSB network configuration. SSB clients will only replicate with other clients using the same configuration.
struct SSBNetwork: Equatable {
    
    /// The name of the network. This is for convenience and is not transmitted, not part of the protocol, nor
    /// Equatable conformance.
    var name: String?
    
    /// The network key. Also called shs or caps.shs.
    var key: NetworkKey
    
    /// A key that will be used to encrypt messages. Also called the signing key or caps.sign.
    var hmac: HMACKey?
    
    static func == (lhs: SSBNetwork, rhs: SSBNetwork) -> Bool {
        lhs.key == rhs.key && lhs.hmac == rhs.hmac
    }
}

class DataKey {

    let data: Data
    let string: String

    init?(base64 string: String) {
        guard let data = Data(base64Encoded: string, options: .ignoreUnknownCharacters) else { return nil }
        if data.count != 32 {
            #if DEBUG
            print("warning: invalid network key. only \(data.count) bytes")
            #endif
            return nil
        }
        self.data = data
        self.string = string
    }

    /// This seems like extra work, but the only way to ensure that
    /// the specified Data is base64 is to encode and decode again.
    /// So, leverage the other init() to do this.
    convenience init?(base64 data: Data) {
        self.init(base64: data.base64EncodedString())
    }

    func hexEncodedString() -> String {
        let bytes = self.data
        
        let hexDigits = Array("0123456789abcdef".utf16)
        var hexChars = [UTF16.CodeUnit]()
        hexChars.reserveCapacity(bytes.count * 2)
    
        for byte in bytes {
        let (index1, index2) = Int(byte).quotientAndRemainder(dividingBy: 16)
            hexChars.append(hexDigits[index1])
            hexChars.append(hexDigits[index2])
        }
    
        return String(utf16CodeUnits: hexChars, count: hexChars.count)
    }
}

// MARK: - Equatable

extension DataKey: Equatable {
    static func == (lhs: DataKey, rhs: DataKey) -> Bool {
        lhs.string == rhs.string
    }
}

// MARK: - Specific keys subclasses

class NetworkKey: DataKey {
    /// TODO: this should be stored in AppConfiguration and then we can get rid of this
    var name: String {
        var name: String?
        switch self {
        case Environment.Networks.mainNet.key:
            name = Environment.Networks.mainNet.name
        case Environment.Networks.test.key:
            name = Environment.Networks.test.name
        default:
            break
        }
        
        if let name = name {
            return name
        } else {
            return string
        }
    }
}

class HMACKey: DataKey {}
