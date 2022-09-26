//
//  Message.swift
//  FBTT
//
//  Created by Christoph on 1/22/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// The basic building block of a Scuttlebutt feed. Messages are data containers (usually JSON) of keys and values that
/// encode some content that the user has posted. Each message is signed by the user's cryptographic key and contains a
/// pointer to the previous message in the feed.
///
/// The type of the message is generally encoded in a "type" field. You can read more about common messages types
/// here: https://patchfox.org/#/message_types/
///
/// You can read more about the structure of feeds and messages in the protocol guide:
/// https://ssbc.github.io/scuttlebutt-protocol-guide/#feeds
struct Message: Codable {

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case timestamp
        case receivedSeq = "ReceiveLogSeq"
        case hashedKey = "HashedKey"
        case offChain = "off_chain"
    }

    let key: MessageIdentifier
    let value: Value
    let timestamp: Float64 // received time in milliseconds since the unix epoch
    // optional, only needed for copy from gobot to viewdb TODO: find a way to stuff this in metadata? i think this requries a custom decoder
    let receivedSeq: Int64?
    let hashedKey: String?
    
    /// A flag that is true if this message is not from a real feed. The `WelcomeService` inserts "fake" messages
    /// into SQLite to help with onboarding.
    let offChain: Bool?
    
    init(
        key: Identifier,
        value: Value,
        timestamp: Float64,
        receivedSeq: Int64 = -1,
        hashedKey: String? = nil,
        offChain: Bool = false
    ) {
        self.key = key
        self.value = value
        self.timestamp = timestamp
        self.receivedSeq = receivedSeq
        self.hashedKey = hashedKey
        self.offChain = offChain
    }
    
    // MARK: Metadata

    struct Metadata {

        struct Author {
            var about: About?
        }

        var author = Author()

        struct Replies {
            
            /// The number of replies to this message
            var count: Int = 0
            
            /// Metadata about the authors of the replies.
            var abouts: Set<About> = Set([])
            
            var isEmpty: Bool {
                // swiftlint:disable empty_count
                count <= 0
                // swiftlint:enable empty_count
            }
        }

        var replies = Replies()

        var isPrivate = false
    }

    var metadata = Metadata()
}

extension Message: Equatable {

    static func == (lhs: Message, rhs: Message) -> Bool {
        lhs.key == rhs.key
    }
}

extension Message: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(self.key)
    }
}

extension Message {

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
