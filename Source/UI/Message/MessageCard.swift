//
//  MessageCard.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

/// This view displays the information we have for an message suitable for being used in a list or grid.
///
/// Use this view inside MessageButton to have nice borders.
struct MessageCard: View {

    var identifierOrMessage: Either<MessageIdentifier, Message>
    var style: CardStyle
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

    @EnvironmentObject
    private var botRepository: BotRepository

    var body: some View {
        ZStack {
            if shouldDisplayChain {
                Path { path in
                    path.move(to: CGPoint(x: 35, y: -4))
                    path.addLine(to: CGPoint(x: 35, y: 15))
                }
                .stroke(style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .fill(Color.secondaryTxt)
            }
            switch style {
            case .compact:
                CompactMessageView(identifierOrMessage: identifierOrMessage, shouldTruncateIfNeeded: true)
            case .golden:
                GoldenMessageView(identifierOrMessage: identifierOrMessage)
            }
        }
    }
}

struct MessageCard_Previews: PreviewProvider {
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

    static var messageWithOneReply: Message {
        var message = Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(
                count: 1,
                abouts: Set(Array(repeating: About(about: .null, image: .null), count: 1))
            ),
            isPrivate: false
        )
        return message
    }

    static var messageWithReplies: Message {
        var message = Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(
                count: 2,
                abouts: Set(Array(repeating: About(about: .null, image: .null), count: 2))
            ),
            isPrivate: false
        )
        return message
    }

    static var messageWithLongAuthor: Message {
        var message = Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: .loremIpsum(words: 8))),
            replies: Message.Metadata.Replies(count: 0, abouts: Set()),
            isPrivate: false
        )
        return message
    }

    static var messageWithUnknownAuthor: Message {
        Message(
            key: "@unset",
            value: messageValue,
            timestamp: 0
        )
    }

    static var previews: some View {
        Group {
            ScrollView {
                VStack(spacing: 0) {
                    MessageCard(message: message, style: .compact)
                    MessageCard(message: messageWithOneReply, style: .compact)
                    MessageCard(message: messageWithReplies, style: .compact)
                    MessageCard(message: messageWithLongAuthor, style: .compact)
                    MessageCard(message: messageWithUnknownAuthor, style: .compact)
                }
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())]) {
                    MessageCard(message: message, style: .golden)
                    MessageCard(message: messageWithOneReply, style: .golden)
                    MessageCard(message: messageWithReplies, style: .golden)
                    MessageCard(message: messageWithLongAuthor, style: .golden)
                    MessageCard(message: messageWithUnknownAuthor, style: .golden)
                }
            }
            ScrollView {
                VStack {
                    MessageCard(message: message, style: .compact)
                    MessageCard(message: messageWithOneReply, style: .compact)
                    MessageCard(message: messageWithReplies, style: .compact)
                    MessageCard(message: messageWithLongAuthor, style: .compact)
                    MessageCard(message: messageWithUnknownAuthor, style: .compact)
                }
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.appBg)
        .injectAppEnvironment(botRepository: BotRepository.fake)
    }
}
