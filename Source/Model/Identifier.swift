//
//  Identifier.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import CryptoKit

enum Algorithm: String, Codable {

    case sha256
    case ed25519
    case ggfeed = "ggfeed-v1"
    case ggfeedmsg = "ggmsg-v1"
    case unsupported

    init() {
        self = .unsupported
    }

    init(fromRawValue: String) {
        self = Algorithm(rawValue: fromRawValue) ?? .unsupported
    }
}

enum Sigil: String, Codable {
    case blob = "&"
    case feed = "@"     // identity is also @
    case message = "%"  // link is also %
    case unsupported
}

// TODO the first character "sigil" % & @ of a hash has special meaning
// @ feed
// % messages
// & blob
// https://ssbc.github.io/docs/ssb/linking.html
// these aliases are temporary to understand the uses
typealias Identifier = String // TOOD: isn't this is a problem? It also pollutes NetworkKey and other strings. i tried to use hexEncodedString() on it, which is not a sigl and thus empty string
typealias Identity = Identifier
typealias BlobIdentifier = Identifier
typealias FeedIdentifier = Identifier
typealias LinkIdentifier = MessageIdentifier
typealias MessageIdentifier = Identifier
typealias InviteIdentifier = Identifier

extension Identifier {

    static let null = "null"
    static let notLoggedIn = "not-logged-in"
    static let unsupported = "unsupported"

    // the first character of the identifier indicating
    // what kind of identifier this is
    var sigil: Sigil {
        if      self.hasPrefix(Sigil.blob.rawValue)         { return .blob }
        else if self.hasPrefix(Sigil.feed.rawValue)         { return .feed }
        else if self.hasPrefix(Sigil.message.rawValue)      { return .message }
        
        else                                                { return .unsupported }
    }

    /// the base64 number between the sigil, marker, and algorithm
    var id: String {
        let components = self.components(separatedBy: ".")
        guard components.count == 2 else { return Identifier.unsupported }
        let component = components[0] as Identifier
        guard component.count > 1 else { return Identifier.unsupported }
        guard component.hasSuffix("=") else { return Identifier.unsupported }
        guard component.sigil != Sigil.unsupported else { return Identifier.unsupported }
        let index = component.index(after: component.startIndex)
        return String(component[index...])
    }
    
    var idBytes: Data? {
        if !self.isValidIdentifier {
            #if DEBUG
            print("warning: invalid identifier:\(self)")
            #endif
            return nil
        }
        guard let data = Data(base64Encoded: self.id, options: .ignoreUnknownCharacters) else { return nil }
        return data
    }
    
    func hexEncodedString() -> String {
        guard let bytes = self.idBytes else {
            return ""
        }
        
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

    // the trailing suffix indicating how the id is encoded
    var algorithm: Algorithm {
        if      self.hasSuffix(Algorithm.sha256.rawValue)   { return .sha256 }
        else if self.hasSuffix(Algorithm.ed25519.rawValue)  { return .ed25519 }
        else if self.hasSuffix(Algorithm.ggfeed.rawValue)   { return .ggfeed }
        else                                                { return .unsupported }
    }

    var isValidIdentifier: Bool {
        return self.sigil != .unsupported &&
            self.id != Identifier.unsupported &&
            self.algorithm != .unsupported
    }

    var isBlob: Bool {
        return self.sigil == .blob
    }

    // TODO: this is a iOS13 specific way to do sha25 hashing....
    // TODO: also it retuns a hex string but i have spent to much time on this already
    var sha256hash: String {
        if #available(iOS 13.0, *) {
            let input = self.data(using: .utf8)!
            let hashed = SHA256.hash(data: input)
            // using description is silly but i couldnt figure out https://developer.apple.com/documentation/cryptokit/sha256digest Accessing Underlying Storage
            let descr = hashed.description
            let prefix = "SHA256 digest: "
            guard descr.hasPrefix(prefix) else { fatalError("oh gawd whhyyyy") }
            return String(descr.dropFirst(prefix.count))
        } else {
            // https://augmentedcode.io/2018/04/29/hashing-data-using-commoncrypto/ ?
            fatalError("TODO: get CommonCrypto method to work or find another swift 5 method")
        }
    }
}

/*
 tl;dr: lets turn
 
 let key = Expression<Data>("key")
 ...
 let rowid = try db.run(self.msgs.insert(
 key <- m.key.asBytes(),
 author <- m.value.author.asBytes(),
 seq <- m.value.sequence,
 rxt <- m.timestamp,
 claimedt <- m.value.timestamp
 ))
 
 into
 
 let key = Expression<Identifier>("key")
 ...
 let rowid = try db.run(self.msgs.insert(
 key <- m.key,
author <- m.value.author,
 seq <- m.value.sequence,
 rxt <- m.timestamp,
 claimedt <- m.value.timestamp
 ))
 
 
 
 cryptix: I'd really like to handle identifiers as their raw values - not in base64
 so we need to be able to encode them as Blobs
 https://github.com/stephencelis/SQLite.swift/blob/master/Documentation/Index.md#custom-types
 
 
 
 but what do i do with this?
 
 import SQLite
 
 extension Identifier: Value {
 public class var declaredDatatype: String {
 return Blob.declaredDatatype
 }
 public class func fromDatatypeValue(blobValue: Blob) -> UIImage {
 // hrm.. might need to know what kind of identifier it is?!
 return // create identifier from blob value
 }
 public var datatypeValue: Blob {
 return // return raw bytes from identifier
 }
 
 }
 */
