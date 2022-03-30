//
//  KeyValue.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

struct KeyValue: Codable {

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case timestamp
        case receivedSeq = "ReceiveLogSeq"
        case hashedKey = "HashedKey"
    }

    let key: Identifier
    let value: Value
    let timestamp: Float64 // received time in milliseconds since the unix epoch
    // optional, only needed for copy from gobot to viewdb TODO: find a way to stuff this in metadata? i think this requries a custom decoder
    let receivedSeq: Int64?
    let hashedKey: String?

    init(key: Identifier, value: Value, timestamp: Float64) {
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.receivedSeq = -1
        self.hashedKey = nil
    }
    
    init(key: Identifier, value: Value, timestamp: Float64, receivedSeq: Int64, hashedKey: String) {
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.receivedSeq = receivedSeq
        self.hashedKey = hashedKey
    }
    
    // MARK: Metadata

    struct Metadata {

        struct Author {
            var about: About?
        }

        var author = Author()

        struct Replies {
            var count: Int = 0
            var abouts: [About] = []
        }

        var replies = Replies()

        var isPrivate = false
    }

    var metadata = Metadata()
}

extension KeyValue: Equatable {

    static func == (lhs: KeyValue, rhs: KeyValue) -> Bool {
        lhs.key == rhs.key
    }
}

extension KeyValue: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
    }
}

extension KeyValue {

    // Convenience var to return the embedded content's type
    var contentType: ContentType {
        self.value.content.type
    }

    // Convenience var for received time as Date
    var receivedDate: Date {
        Date(timeIntervalSince1970: self.timestamp)
    }

    var receivedDateString: String {
        DateFormatter.localizedString(from: self.receivedDate,
                                             dateStyle: .short,
                                             timeStyle: .short)
    }
    
    // Convenience var for user time as Date
    var userDate: Date {
        let ud = Date(timeIntervalSince1970: self.value.timestamp / 1_000)
        let now = Date(timeIntervalSinceNow: 0)
        if ud > now {
            return Date(timeIntervalSince1970: self.timestamp / 1_000)
        }
        return ud
    }

    var userDateString: String {
        DateFormatter.localizedString(from: self.userDate,
                                             dateStyle: .short,
                                             timeStyle: .short)
    }
}
