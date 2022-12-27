//
//  MessageStack.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// A stack of messages. The primary purpose of this view is to be used in the Profile screen
/// inside the ScrollView defined in that screen. For most cases, consider using MessageList instead
/// that already integrates a ScrollView.
struct MessageStack<DataSource>: View where DataSource: MessageDataSource {
    @ObservedObject
    var dataSource: DataSource

    var body: some View {
        InfiniteStack(dataSource: dataSource) { message in
            if let message = message as? Message {
                MessageButton(message: message)
            }
        }
    }
}

struct MessageStack_Previews: PreviewProvider {
    static var messageValue: MessageValue {
        MessageValue(
            author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            content: Content(
                from: Post(
                    blobs: nil,
                    branches: nil,
                    hashtags: nil,
                    mentions: nil,
                    root: nil,
                    text: .loremIpsum(words: 10)
                )
            ),
            hash: "",
            previous: nil,
            sequence: 0,
            signature: .null,
            claimedTimestamp: 0
        )
    }
    static var message: Message {
        var message = Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(count: 0, abouts: Set()),
            isPrivate: false
        )
        return message
    }
    static var previews: some View {
        MessageStack(dataSource: StaticMessageDataSource(messages: [message]))
    }
}
