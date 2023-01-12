//
//  MessageButton.swift
//  Planetary
//
//  Created by Martin Dutra on 21/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageButton: View {
    var message: Message
    var style = CardStyle.compact

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Button {
            if let contact = message.content.contact {
                appController.open(identity: contact.contact)
            } else {
                appController.open(identifier: message.id)
            }
        } label: {
            MessageCard(message: message, style: style)
        }
        .buttonStyle(CardButtonStyle())
    }
}

struct MessageButton_Previews: PreviewProvider {
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
        Group {
            MessageButton(message: message)
            MessageButton(message: message, style: .golden)
            MessageButton(message: message)
                .preferredColorScheme(.dark)
        }
        .environmentObject(AppController.shared)
    }
}
