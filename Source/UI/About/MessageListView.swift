//
//  MessageListView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

struct MessageListView: View {

    var strategy: FeedStrategy

    @EnvironmentObject
    private var botRepository: BotRepository

    @State
    private var messages = [Message]()
    
    @State
    private var isLoading = false

    @State
    private var offset = 0

    @State
    private var noMoreMessages = false
    
    var body: some View {
        ZStack {
            LazyVStack {
                if messages.isEmpty, !isLoading {
                    EmptyPostsView(description: Localized.Message.noPostsDescription)
                } else {
                    ForEach(messages, id: \.self) { message in
                        Button {
                            if let contact = message.content.contact {
                                AppController.shared.open(identity: contact.contact)
                            } else {
                                AppController.shared.open(identifier: message.id)
                            }
                        } label: {
                            MessageView(message: message)
                                .onAppear {
                                    if message == messages.last {
                                        loadMore()
                                    }
                                }
                        }
                        .buttonStyle(MessageButtonStyle())
                    }
                }
                if isLoading, !noMoreMessages {
                    HStack {
                        ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                    }
                }
            }
            .frame(maxWidth: 500)
            .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
        }
        .frame(maxWidth: .infinity)
        .task { loadMore() }
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
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
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
                MessageListView(strategy: StaticAlgorithm(messages: []))
                ScrollView {
                    MessageListView(strategy: StaticAlgorithm(messages: [sample, another]))
                }
            }
            VStack {
                MessageListView(strategy: StaticAlgorithm(messages: []))
                ScrollView {
                    MessageListView(strategy: StaticAlgorithm(messages: [sample, another]))
                }
            }
            .preferredColorScheme(.dark)
        }
        .padding()
        .background(Color.cardBackground)
        .environmentObject(BotRepository.shared)
    }
}
