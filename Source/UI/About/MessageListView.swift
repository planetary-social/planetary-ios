//
//  MessageListView.swift
//  Planetary
//
//  Created by Martin Dutra on 25/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct MessageListView<Header>: View where Header: View {

    @EnvironmentObject
    var bot: BotRepository

    @State var messages = [Message]()
    var strategy: FeedStrategy
    @ViewBuilder var header: () -> Header

    @State fileprivate var isLoading = false
    @State fileprivate var offset = 0
    @State fileprivate var noMoreMessages = false
    
    var body: some View {
        LazyVStack(pinnedViews: [.sectionHeaders]) {
            Section(content: {
                if let messages = messages {
                    ForEach(messages, id: \.self) { message in
                        MessageView(message: message)
                            .onAppear {
                                if message == messages.last {
                                    loadMore()
                                }
                            }
                            .padding()
                    }
                }
                if isLoading, !noMoreMessages {
                    HStack {
                        ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                    }
                }
            }, header: header).task { loadMore() }
        }
    }

    func loadMore() {
        guard !isLoading else {
            return
        }
        isLoading = true
        Task {
            let pageSize = 10
            do {
                let newMessages = try await bot.current.feed(strategy: strategy, limit: pageSize, offset: offset)
                messages.append(contentsOf: newMessages)
                offset += newMessages.count
                noMoreMessages = newMessages.count < pageSize
            } catch {

            }
            isLoading = false
        }
    }
}

let sampleMessage = Message(
    key: "%12345",
    value: MessageValue(
        author: "@4Wxraodifldsjf=.ed25519",
        content: Content(
            from: Post(text: "Hello, world")
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

struct MessageListView_Previews: PreviewProvider {

    static var previews: some View {
        MessageListView(messages: [sampleMessage], strategy: NoHopFeedAlgorithm(identity: .null)) {

        }
    }
}
