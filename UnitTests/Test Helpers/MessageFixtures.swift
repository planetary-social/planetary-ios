//
//  MessageFixtures.swift
//  UnitTests
//
//  Created by Matthew Lorentz on 1/19/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

// swiftlint:disable force_unwrapping force_try

/// Easy access to `Message` data for testing.
enum MessageFixtures {
    static let messageWithReceivedSeq = message(fromFixture: "MessageWithReceivedSeq.json")
    
    static func message(
        key: MessageIdentifier = "TestPostId=.ed25519",
        sequence: Int,
        content: Content,
        timestamp: Float64 = 2_684_029_486_000, // 2055
        receivedTimestamp: Float64 = 2_684_029_486_000, // 2055
        receivedSeq: Int64 = 0, // largest in example feed is 77
        author: Identity
    ) -> Message {
        Message(
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
        post: Post = Post(text: "post"),
        author: Identity
    ) -> Message {
            
        message(
            key: key,
            sequence: sequence,
            content: Content(from: post),
            timestamp: timestamp,
            receivedTimestamp: receivedTimestamp,
            receivedSeq: receivedSeq,
            author: author
        )
    }
    
    // Convenience func to load and return JSON resource file as Data.
    static func message(fromFixture jsonResourceName: String) -> Message {
        let url = Bundle.current.url(forResource: jsonResourceName, withExtension: nil)!
        let data = try! Data(contentsOf: url)
        return try! JSONDecoder().decode(Message.self, from: data)
    }
}
