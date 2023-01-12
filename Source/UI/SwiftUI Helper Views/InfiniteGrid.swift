//
//  InfiniteGrid.swift
//  Planetary
//
//  Created by Martin Dutra on 27/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import SwiftUI

struct InfiniteGrid<DataSource, Content>: View where DataSource: InfiniteDataSource, Content: View {

    @ObservedObject var dataSource: DataSource
    let content: (DataSource.CachedCollection.Element) -> Content

    private var shouldShowAlert: Binding<Bool> {
        Binding {
            dataSource.errorMessage != nil
        } set: { _ in
            dataSource.errorMessage = nil
        }
    }

    init(
        dataSource: DataSource,
        @ViewBuilder content: @escaping (DataSource.CachedCollection.Element) -> Content
    ) {
        self.dataSource = dataSource
        self.content = content
    }

    let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible())]

    var body: some View {
        Group {
            if let cache = dataSource.cache {
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack(alignment: .top) {
                        LazyVGrid(columns: columns, spacing: 14) {
                            if cache.isEmpty {
                                EmptyView()
                            } else {
                                ForEach(cache, id: \.self) { item in
                                    content(item)
                                        .onAppear {
                                            if item == cache.last {
                                                Task {
                                                    await dataSource.loadMore()
                                                }
                                            }
                                        }
                                }
                                if dataSource.isLoadingMore {
                                    HStack {
                                        ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: 500)
                        .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                LoadingView()
            }
        }
        .task {
            if dataSource.cache == nil {
                await dataSource.loadFromScratch()
            }
        }
        .refreshable {
            await dataSource.loadFromScratch()
        }
        .alert(
            Localized.error.text,
            isPresented: shouldShowAlert,
            actions: {
                Button(Localized.tryAgain.text) {
                    Task {
                        await dataSource.loadFromScratch()
                    }
                }
                Button(Localized.cancel.text, role: .cancel) {
                    shouldShowAlert.wrappedValue = false
                }
            },
            message: {
                Text(dataSource.errorMessage ?? "")
            }
        )
    }
}

struct InfiniteGrid_Previews: PreviewProvider {
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
    static var second: Message {
        var message = Message(
            key: "@unset2",
            value: MessageValue(
                author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
                content: Content(
                    from: Post(
                        blobs: nil,
                        branches: nil,
                        hashtags: nil,
                        mentions: nil,
                        root: nil,
                        text: .loremIpsum(words: 2)
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
    static var third: Message {
        var message = Message(
            key: "@unset3",
            value: MessageValue(
                author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
                content: Content(
                    from: Post(
                        blobs: nil,
                        branches: nil,
                        hashtags: nil,
                        mentions: nil,
                        root: nil,
                        text: .loremIpsum(words: 3)
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
    static var fourth: Message {
        var message = Message(
            key: "@unset4",
            value: MessageValue(
                author: "@QW5uYVZlcnNlWFhYWFhYWFhYWFhYWFhYWFhYWFhYWFg=.ed25519",
                content: Content(
                    from: Post(
                        blobs: nil,
                        branches: nil,
                        hashtags: nil,
                        mentions: nil,
                        root: nil,
                        text: .loremIpsum(words: 8)
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
        InfiniteGrid(dataSource: StaticMessageDataSource(messages: [message, second, third, fourth])) { message in
            MessageButton(message: message, style: .golden)
        }
        .injectAppEnvironment(botRepository: .fake, appController: .shared)
    }
}
