//
//  MessageListView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageListView: View {

    @State
    var messages = [Message]()

    var strategy: FeedStrategy

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var isLoading = false

    @State
    private var offset = 0

    @State
    private var noMoreMessages = false

    private let howGossippingWorks = "https://github.com/planetary-social/planetary-ios/wiki/Distributed-Social-Network"
    
    var body: some View {
        LazyVStack {
            if messages.isEmpty, !isLoading {
                Text("⏳")
                    .font(.system(size: 68))
                    .padding()
                    .padding(.top, 35)
                Text(Localized.Message.noPostsTitle.text)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primaryTxt)
                Text(noPostsDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondaryTxt)
                    .accentColor(.accentTxt)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                ForEach(messages, id: \.self) { message in
                    MessageView(message: message)
                        .onAppear {
                            if message == messages.last {
                                loadMore()
                            }
                        }
                        .padding(EdgeInsets(top: 15, leading: 15, bottom: 0, trailing: 15))
                        .compositingGroup()
                        .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
                        .shadow(color: .cardShadowBottom, radius: 10, x: 0, y: 4)
                }
            }
            if isLoading, !noMoreMessages {
                HStack {
                    ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                }
            }
        }
        .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
        .task { loadMore() }
    }

    var noPostsDescription: AttributedString {
        let unformattedDescription = Localized.Message.noPostsDescription.text(["link": howGossippingWorks])
        do {
            return try AttributedString(
                markdown: unformattedDescription,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            return AttributedString(unformattedDescription)
        }
    }

    func loadMore() {
        guard !isLoading else {
            return
        }
        isLoading = true
        Task.detached {
            let bot = await botRepository.current
            let pageSize = 50
            do {
                let newMessages = try await bot.feed(strategy: strategy, limit: pageSize, offset: offset)
                await MainActor.run {
                    messages.append(contentsOf: newMessages)
                    offset += newMessages.count
                    noMoreMessages = newMessages.count < pageSize
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

struct MessageListView_Previews: PreviewProvider {

    static var sample: Message {
        var message = Message(
            key: "%12345",
            value: MessageValue(
                author: "@4Wxraodifldsjf=.ed25519",
                content: Content(
                    from: Post(text: .loremIpsum(1))
                ),
                hash: "akldsjfa",
                previous: nil,
                sequence: 0,
                signature: "%alksdjfadsfi",
                claimedTimestamp: 345
            ),
            timestamp: 356,
            receivedSeq: 0,
            hashedKey: nil,
            offChain: false
        )
        message.metadata = Message.Metadata(
            author: Message.Metadata.Author(about: About(about: .null, name: "Mario")),
            replies: Message.Metadata.Replies(count: 0, abouts: Set()),
            isPrivate: false
        )
        return message
    }

    static var another: Message {
        var message = Message(
            key: "%32346",
            value: MessageValue(
                author: "@4Wxraodifldsjf=.ed25519",
                content: Content(
                    from: Post(text: .loremIpsum(1))
                ),
                hash: "vkldsjfa",
                previous: nil,
                sequence: 0,
                signature: "%blksdjfadsfi",
                claimedTimestamp: 345
            ),
            timestamp: 356,
            receivedSeq: 1,
            hashedKey: nil,
            offChain: false
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
                MessageListView(messages: [], strategy: NoHopFeedAlgorithm(identity: .null))
                MessageListView(messages: [sample, another], strategy: NoHopFeedAlgorithm(identity: .null))
            }
            VStack {
                MessageListView(messages: [], strategy: NoHopFeedAlgorithm(identity: .null))
                MessageListView(messages: [sample, another], strategy: NoHopFeedAlgorithm(identity: .null))
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.fake)
    }
}
