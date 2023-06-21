//
//  MessageButton.swift
//  Planetary
//
//  Created by Martin Dutra on 21/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays the a button with the information we have for an message suitable for being used in a list
/// or grid.
///
/// The button opens ThreadViewController when tapped.
struct MessageButton: View {

    var identifierOrMessage: Either<MessageIdentifier, Message>
    var style: CardStyle

    // If true, it displays a chain line above the card
    var shouldDisplayChain: Bool

    init(identifier: MessageIdentifier, style: CardStyle, shouldDisplayChain: Bool = false) {
        self.init(identifierOrMessage: .left(identifier), style: style, shouldDisplayChain: shouldDisplayChain)
    }

    init(message: Message, style: CardStyle, shouldDisplayChain: Bool = false) {
        self.init(identifierOrMessage: .right(message), style: style, shouldDisplayChain: shouldDisplayChain)
    }

    init(identifierOrMessage: Either<MessageIdentifier, Message>, style: CardStyle, shouldDisplayChain: Bool) {
        self.identifierOrMessage = identifierOrMessage
        self.style = style
        self.shouldDisplayChain = shouldDisplayChain
    }

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Button {
            appController.open(identifier: identifierOrMessage.id)
        } label: {
            MessageCard(identifierOrMessage: identifierOrMessage, style: style, shouldDisplayChain: shouldDisplayChain)
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
            MessageButton(message: message, style: .compact)
            MessageButton(message: message, style: .golden)
            MessageButton(message: message, style: .compact)
                .preferredColorScheme(.dark)
        }
        .environmentObject(AppController.shared)
    }
}
