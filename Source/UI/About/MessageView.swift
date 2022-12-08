//
//  MessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageView: View {

    var message: Message

    var attributedHeader: AttributedString? {
        let name = message.metadata.author.about?.name?.trimmedForSingleLine ?? String(message.author.prefix(7))
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
        let string = localized.text(["somebody": "**\(name)**"])
        do {
            var attributed = try AttributedString(markdown: string)
            if let range = attributed.range(of: name) {
                attributed[range].foregroundColor = .primaryTxt
            }
            return attributed
        } catch {
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Button {
                    AppController.shared.open(identity: message.author)
                } label: {
                    HStack(alignment: .center) {
                        AvatarView(metadata: message.metadata.author.about?.image, size: 24)
                        if let header = attributedHeader {
                            Text(header)
                                .lineLimit(2)
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
                CompactIdentityView(identity: contact.contact)
                    .onTapGesture {
                        AppController.shared.open(identity: contact.contact)
                    }
            } else if let post = message.content.post {
                Group {
                    CompactPostView(post: post)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    AppController.shared.open(identifier: message.id)
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
        .cornerRadius(20)
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
        .compositingGroup()
        .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
        .shadow(color: .cardShadowBottom, radius: 10, x: 0, y: 4)
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

struct MessageView_Previews: PreviewProvider {
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
                    MessageView(message: message)
                    MessageView(message: messageWithOneReply)
                    MessageView(message: messageWithReplies)
                    MessageView(message: messageWithLongAuthor)
                    MessageView(message: messageWithUnknownAuthor)
                }
            }
            ScrollView {
                VStack {
                    MessageView(message: message)
                    MessageView(message: messageWithOneReply)
                    MessageView(message: messageWithReplies)
                    MessageView(message: messageWithLongAuthor)
                    MessageView(message: messageWithUnknownAuthor)
                }
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.appBg)
        .environmentObject(BotRepository.fake)
    }
}
