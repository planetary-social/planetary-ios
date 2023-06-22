//
//  LikeButton.swift
//  Planetary
//
//  Created by Martin Dutra on 17/3/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

struct LikeButton: View {

    var message: Message
    var liked: Bool

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else {
                Button {
                    Analytics.shared.trackDidTapButton(buttonName: "like")
                    like()
                } label: {
                    if liked {
                        Image.iconLiked
                    } else {
                        Image.iconLike
                    }
                }
                .disabled(liked)
            }
        }
        .frame(width: 18, height: 18, alignment: .center)
    }

    private func like() {
        // TODO: Check root and branches
        let vote = ContentVote(
            link: message.key,
            value: 1,
            expression: "💜",
            root: message.key,
            branches: [message.key]
        )
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let bot = await botRepository.current
            do {
                try await bot.publish(content: vote)
                await MainActor.run {
                    isLoading = false
                    NotificationCenter.default.post(.didPublishVote(to: vote.vote.link))
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    // show alert
                    isLoading = false
                }
            }
        }
    }
}

struct LikeButton_Previews: PreviewProvider {
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
            VStack {
                LikeButton(message: message, liked: false)
                LikeButton(message: message, liked: true)
            }
            VStack {
                LikeButton(message: message, liked: false)
                LikeButton(message: message, liked: true)
            }
            .preferredColorScheme(.dark)
        }
        .injectAppEnvironment(botRepository: .fake)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBg)
    }
}
