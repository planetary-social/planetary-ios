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

    var message: Message
    var style = CardStyle.compact

    @EnvironmentObject
    private var appController: AppController

    private var author: About {
        About(
            identity: message.author,
            name: message.metadata.author.about?.name,
            description: nil,
            image: message.metadata.author.about?.image,
            publicWebHosting: nil
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch style {
            case .compact:
                HStack(alignment: .center) {
                    Button {
                        appController.open(identity: author.identity)
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
                }
                .padding(10)
                Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                if let contact = message.content.contact {
                    IdentityCard(identity: contact.contact, style: .compact)
                } else if let post = message.content.post {
                    Group {
                        CompactPostView(identifier: message.id, post: post)
                        Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                        HStack {
                            StackedAvatarsView(avatars: replies, size: 20, border: 0)
                            if let replies = attributedReplies {
                                Text(replies)
                                    .font(.subheadline)
                                    .foregroundColor(Color.secondaryTxt)
                            }
                            Spacer()
                            Image.buttonReply
                        }
                        .padding(15)
                    }
                }
            case .golden:
                if let contact = message.content.contact {
                    GoldenIdentityView(identity: contact.contact)
                } else if let post = message.content.post {
                    GoldenPostView(identifier: message.id, post: post, author: author)
                }
            }
        }
        .background(
            LinearGradient(
                colors: [Color.cardBgTop, Color.cardBgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .cornerRadius(cornerRadius)
        .padding(padding)
    }

    private var attributedHeader: AttributedString? {
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

    var padding: EdgeInsets {
        switch style {
        case .golden:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .compact:
            return EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15)
        }
    }

    var cornerRadius: CGFloat {
        switch style {
        case .golden:
            return 15
        case .compact:
            return 20
        }
    }

    private var replies: [ImageMetadata] {
        Array(message.metadata.replies.abouts.compactMap { $0.image }.prefix(2))
    }

    private var attributedReplies: AttributedString? {
        guard !message.metadata.replies.isEmpty else {
            return nil
        }
        let replyCount = message.metadata.replies.count
        let localized = replyCount == 1 ? Localized.Reply.one : Localized.Reply.many
        let string = localized.text(["count": "**\(replyCount)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: "\(replyCount)") {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
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
                VStack {
                    MessageCard(message: message)
                    MessageCard(message: messageWithOneReply)
                    MessageCard(message: messageWithReplies)
                    MessageCard(message: messageWithLongAuthor)
                    MessageCard(message: messageWithUnknownAuthor)
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
                    MessageCard(message: message)
                    MessageCard(message: messageWithOneReply)
                    MessageCard(message: messageWithReplies)
                    MessageCard(message: messageWithLongAuthor)
                    MessageCard(message: messageWithUnknownAuthor)
                }
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
        .environmentObject(AppController.shared)
    }
}
