//
//  MessageHeaderView.swift
//  Planetary
//
//  Created by Martin Dutra on 30/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageHeaderView: View {

    var identifier: MessageIdentifier
    var message: Message?

    init(identifier: MessageIdentifier) {
        self.identifier = identifier
    }

    init(message: Message) {
        self.identifier = message.id
        self.message = message
    }

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        HStack(alignment: .center) {
            if let message = message {
                Button {
                    appController.open(identity: message.author)
                } label: {
                    HStack(alignment: .center) {
                        AvatarView(metadata: author.image, size: 24)
                        if let header = attributedHeader {
                            Text(header)
                                .lineLimit(1)
                                .font(.subheadline)
                                .foregroundColor(Color.secondaryTxt)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                MessageOptionsButton(message: message)
            } else {
                Spacer()
                MessageOptionsButton(identifier: identifier)
            }
        }
        .padding(10)
    }

    private var author: About {
        guard let message = message else {
            return About(about: .null)
        }
        return About(
            identity: message.author,
            name: message.metadata.author.about?.name,
            description: nil,
            image: message.metadata.author.about?.image,
            publicWebHosting: nil
        )
    }
    
    private var attributedHeader: AttributedString? {
        guard let message = message else {
            return nil
        }
        var localized: Localized
        switch message.contentType {
        case .post:
            guard let post = message.content.post else {
                return nil
            }
            if post.isRoot {
                localized = .posted
            } else {
                localized = .replied
            }
        case .contact:
            guard let contact = message.content.contact else {
                return nil
            }
            if contact.isBlocking {
                localized = .startedBlocking
            } else if contact.isFollowing {
                localized = .startedFollowing
            } else {
                localized = .stoppedFollowing
            }
        case .vote:
            localized = .reacted
        default:
            return nil
        }
        let string = localized.text(["somebody": "**\(author.displayName)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: author.displayName) {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }
}

struct MessageHeaderView_Previews: PreviewProvider {
    static var messageValue: MessageValue {
        MessageValue(
            author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
            content: Content(
                from: Post(
                    blobs: nil,
                    branches: nil,
                    hashtags: nil,
                    mentions: nil,
                    root: "%somepost",
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
            MessageHeaderView(message: message)
            MessageHeaderView(message: message)
                .preferredColorScheme(.dark)
        }
        .padding()
        .background(LinearGradient.cardGradient)
        .injectAppEnvironment(botRepository: .fake)
    }
}
