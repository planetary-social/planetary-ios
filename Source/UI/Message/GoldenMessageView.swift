//
//  GoldenMessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 21/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct GoldenMessageView: View {

    var identifierOrMessage: Either<MessageIdentifier, Message>

    init(identifier: MessageIdentifier) {
        self.init(identifierOrMessage: .left(identifier))
    }

    init(message: Message) {
        self.init(identifierOrMessage: .right(message))
    }

    init(identifierOrMessage: Either<MessageIdentifier, Message>) {
        self.identifierOrMessage = identifierOrMessage
    }
    
    private var message: Message? {
        switch identifierOrMessage {
        case .left:
            return nil
        case .right(let message):
            return message
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                if let message = message {
                    if let contact = message.content.contact {
                        GoldenIdentityView(
                            identity: contact.contact
                        )
                    } else if let post = message.content.post {
                        GoldenPostView(
                            identifier: message.id,
                            post: post,
                            author: About(
                                identity: message.author,
                                name: message.metadata.author.about?.name,
                                description: nil,
                                image: message.metadata.author.about?.image,
                                publicWebHosting: nil
                            )
                        )
                    }
                } else {
                    VStack(alignment: .center, spacing: 15) {
                        Spacer(minLength: 0)
                        Image.messageNotVisible
                            .renderingMode(.template)
                            .foregroundColor(.primaryTxt)
                        Text("This message is hidden because the user's profile and information are private")
                            .foregroundColor(.secondaryTxt)
                            .multilineTextAlignment(.center)
                        Spacer(minLength: 0)
                    }
                    .padding(15)
                }
            }
            .background(
                LinearGradient.cardGradient
            )
            .cornerRadius(15)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
        }
    }
}

struct GoldenMessageView_Previews: PreviewProvider {
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
    static var follow: Message {
        var message = Message(
            key: "@unset",
            value: MessageValue(
                author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
                content: Content(
                    from: Contact(
                        contact: .null,
                        following: true
                    )
                ),
                hash: "",
                previous: nil,
                sequence: 0,
                signature: .null,
                claimedTimestamp: 0
            ),
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
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                GoldenMessageView(identifier: "%unset")
                GoldenMessageView(message: message)
                GoldenMessageView(message: follow)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                GoldenMessageView(message: message)
                GoldenMessageView(message: follow)
            }
            .preferredColorScheme(.dark)
        }
        .padding(10)
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
