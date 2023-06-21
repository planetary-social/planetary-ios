//
//  CompactMessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 21/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct CompactMessageView: View {

    var identifierOrMessage: Either<MessageIdentifier, Message>

    var shouldTruncateIfNeeded: Bool

    var didTapReply: (() -> Void)?

    @State
    private var liked: Bool?

    @EnvironmentObject
    private var appController: AppController

    @EnvironmentObject
    private var botRepository: BotRepository

    private var message: Message? {
        switch identifierOrMessage {
        case .left:
            return nil
        case .right(let message):
            return message
        }
    }

    init(identifier: MessageIdentifier) {
        self.init(
            identifierOrMessage: .left(identifier),
            shouldTruncateIfNeeded: true,
            didTapReply: nil
        )
    }

    init(message: Message, shouldTruncateIfNeeded: Bool, didTapReply: (() -> Void)? = nil) {
        self.init(
            identifierOrMessage: .right(message),
            shouldTruncateIfNeeded: shouldTruncateIfNeeded,
            didTapReply: didTapReply
        )
    }

    init(
        identifierOrMessage: Either<MessageIdentifier, Message>,
        shouldTruncateIfNeeded: Bool = true,
        didTapReply: (() -> Void)? = nil
    ) {
        self.identifierOrMessage = identifierOrMessage
        self.shouldTruncateIfNeeded = shouldTruncateIfNeeded
        self.didTapReply = didTapReply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let message = message {
                MessageHeaderView(message: message)
                Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                if let contact = message.content.contact?.contact {
                    Button {
                        AppController.shared.open(identity: contact)
                    } label: {
                        IdentityCard(identity: contact, style: .compact)
                    }
                } else if let post = message.content.post {
                    CompactPostView(identifier: message.id, post: post, lineLimit: shouldTruncateIfNeeded ? 5 : nil)
                } else if let vote = message.content.vote {
                    CompactVoteView(identifier: message.id, vote: vote.vote)
                }
                Divider()
                    .overlay(Color.cardDivider)
                    .shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                HStack(alignment: .center, spacing: 15) {
                    if !replies.isEmpty {
                        StackedAvatarsView(avatars: replies, size: 20, border: 0)
                    }
                    if let replies = attributedReplies {
                        Text(replies)
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryTxt)
                    }
                    Spacer()
                    Group {
                        if let didTapReply = didTapReply {
                            Button {
                                didTapReply()
                            } label: {
                                Image.buttonReply
                            }
                        } else {
                            NavigationLink {
                                MessageView(message: message, shouldOpenCompose: true, bot: botRepository.current)
                                    .injectAppEnvironment(botRepository: botRepository, appController: appController)
                            } label: {
                                Image.buttonReply
                            }
                        }
                        if let liked = liked {
                            LikeButton(message: message, liked: liked)
                        } else {
                            ProgressView()
                        }
                    }
                    .frame(width: 18, height: 18, alignment: .center)
                }
                .padding(15)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    MessageHeaderView(identifier: identifierOrMessage.id)
                    Divider()
                        .overlay(Color.cardDivider)
                        .shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                    VStack(alignment: .center, spacing: 15) {
                        Image.messageNotVisible
                            .renderingMode(.template)
                            .foregroundColor(.primaryTxt)
                        Text("This message is hidden because the user's profile and information are private")
                            .foregroundColor(.secondaryTxt)
                            .multilineTextAlignment(.center)
                    }
                    .padding(15)
                }
            }
        }
        .background(
            LinearGradient.cardGradient
        )
        .cornerRadius(20)
        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
        .onReceive(NotificationCenter.default.publisher(for: .didPublishVote)) { notification in
            guard let identifier = notification.identifier else {
                return
            }
            if identifier == message?.key {
                liked = nil
                Task {
                    await loadLikedIfNeeded()
                }
            }
        }
        .task(id: message, priority: .userInitiated) {
            await loadLikedIfNeeded()
        }
    }

    private func loadLikedIfNeeded() async {
        guard let message = message else {
            return
        }
        guard liked == nil else {
            return
        }
        let identifier = message.id
        let bot = botRepository.current
        guard let author = bot.identity else {
            return
        }
        do {
            let result = try await bot.likes(identifier: identifier, by: author)
            await MainActor.run {
                liked = result
            }
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
            await MainActor.run {
                liked = nil
            }
        }
    }

    private var replies: [ImageMetadata] {
        guard let message = message else {
            return []
        }
        return Array(message.metadata.replies.abouts.compactMap { $0.image }.prefix(2))
    }

    private var attributedReplies: AttributedString? {
        guard let message = message else {
            return nil
        }
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

struct CompactMessageView_Previews: PreviewProvider {
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
        VStack {
            CompactMessageView(identifier: "%unset")
            CompactMessageView(message: message, shouldTruncateIfNeeded: true)
        }
        .padding()
        .background(Color.appBg)
        .injectAppEnvironment(botRepository: .fake, appController: .shared)
    }
}
