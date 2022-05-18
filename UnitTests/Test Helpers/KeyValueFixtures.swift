//
//  KeyValueFixtures.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

// swiftlint:disable force_unwrapping force_try

/// Easy access to `KeyValue` data for testing.
enum KeyValueFixtures {
    static let keyValueWithReceivedSeq = keyValue(fromFixture: "KeyValueWithReceivedSeq.json")
    
    static func keyValue(
        key: MessageIdentifier = "TestPostId=.ed25519",
        sequence: Int,
        content: Content,
        timestamp: Float64 = 2_684_029_486_000, // 2055
        receivedTimestamp: Float64 = 2_684_029_486_000, // 2055
        receivedSeq: Int64 = 0, // largest in example feed is 77
        author: Identity
    ) -> KeyValue {
        KeyValue(
            key: key,
            value: Value(
                author: author,
                content: content,
                hash: "hash",
                previous: nil,
                sequence: sequence,
                signature: Identifier("signature"),
                timestamp: timestamp
            ),
            timestamp: receivedTimestamp,
            receivedSeq: receivedSeq,
            hashedKey: "hashedKey"
        )
    }
    
    static func post(
        key: MessageIdentifier = "TestPostId=.ed25519",
        sequence: Int = 0,
        timestamp: Float64 = 2_684_029_486_000, // 2055
        receivedTimestamp: Float64 = 2_684_029_486_000, // 2055
        receivedSeq: Int64 = 0, // largest in example feed is 77
        author: Identity
    ) -> KeyValue {
            
        keyValue(
            key: key,
            sequence: sequence,
            content: Content(from: Post(text: "post")),
            timestamp: timestamp,
            receivedTimestamp: receivedTimestamp,
            receivedSeq: receivedSeq,
            author: author
        )
    }
    
    // Convenience func to load and return JSON resource file as Data.
    static func keyValue(fromFixture jsonResourceName: String) -> KeyValue {
        let url = Bundle.current.url(forResource: jsonResourceName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(KeyValue.self, from: data)
    }
}
