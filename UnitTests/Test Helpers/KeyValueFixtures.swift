//
//  KeyValueFixtures.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Easy access to `KeyValue` data for testing.
struct KeyValueFixtures {
    static let keyValueWithReceivedSeq = keyValue(fromFixture: "KeyValueWithReceivedSeq.json")
    
    static func keyValue(
        key: MessageIdentifier = "TestPostId=.ed25519",
        timestamp: Float64 = 2_684_029_486_000, // 2055
        receivedTimestamp: Float64 = 2_684_029_486_000, // 2055
        receivedSeq: Int64 = 0, // largest in example feed is 77
        author: Identity) -> KeyValue {
        KeyValue(
            key: key,
            value: Value(
                author: author,
                content: Content(from: Post(text: "post")),
                hash: "hash",
                previous: nil,
                sequence: 0,
                signature: Identifier("signature"),
                timestamp: timestamp
            ),
            timestamp: receivedTimestamp,
            receivedSeq: receivedSeq,
            hashedKey: "hashedKey"
        )
    }
    
    // Convenience func to load and return JSON resource file as Data.
    static func keyValue(fromFixture jsonResourceName: String) -> KeyValue {
        let url = Bundle.current.url(forResource: jsonResourceName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(KeyValue.self, from: data)
    }
}
