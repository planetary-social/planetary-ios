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
    var type: MessageView.`Type` = .compact

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
            MessageView(message: message, type: type)
        }
        .buttonStyle(MessageButtonStyle())
    }
}

fileprivate struct MessageButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(y: configuration.isPressed ? 3 : 0)
            .compositingGroup()
            .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
            .shadow(
                color: .cardShadowBottom,
                radius: configuration.isPressed ? 5 : 10,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
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
            MessageButton(message: message, type: .golden)
            MessageButton(message: message)
                .preferredColorScheme(.dark)
        }
        .environmentObject(AppController.shared)
    }
}
