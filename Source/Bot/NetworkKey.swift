//
//  Root.swift
//  FBTT
//
//  Created by Christoph on 2/4/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

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

// MARK:- Equatable

extension DataKey: Equatable {
    static func == (lhs: DataKey, rhs: DataKey) -> Bool {
        return lhs.string == rhs.string
    }
}

// MARK:- Specific keys subclasses

class NetworkKey: DataKey {

    // SSB default network
    static let ssb = NetworkKey(base64: Environment.DefaultNetwork.key)!

    // Verse development network
    // Generated from "Verse Communications, Inc." string
    static let verse = NetworkKey(base64: Environment.DevelopmentNetwork.key)!

    // Verse testing network
    // auto-deploy network for CI testing, will be scrubbed
    static let integrationTests = NetworkKey(base64: Environment.TestingNetwork.key)!
    
    // Planetary develpoment network for the new format
    static let planetary = NetworkKey(base64: Environment.PlanetaryNetwork.key)!
    
    static let planetaryTest = NetworkKey(base64: Environment.TestingNetwork.key)!

    var name: String {
        if self == NetworkKey.ssb { return Environment.DefaultNetwork.name }
        else if self == NetworkKey.integrationTests { return Environment.TestingNetwork.name }
        else if self == NetworkKey.planetary { return Environment.PlanetaryNetwork.name }
        else { return Environment.DevelopmentNetwork.name }
    }
}

class HMACKey: DataKey {

    // SSB default network
    // there is no HMAC key for the SSB network

    // development network
    static let verse = HMACKey(base64: Environment.DevelopmentNetwork.hmac)!
    
    // automated testing network
    static let integrationTests = HMACKey(base64: Environment.TestingNetwork.hmac)!

    // Next HMAC key
    static let planetary = HMACKey(base64: Environment.PlanetaryNetwork.hmac)!
    
    static let planetaryTest = HMACKey(base64: Environment.TestingNetwork.hmac)!
}
