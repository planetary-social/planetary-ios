//
//  MessageView.swift
//  Planetary
//
//  Created by Martin Dutra on 12/2/23.
//  Copyright © 2023 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Logger
import SwiftUI

enum MessageViewBuilder {
    static func build(
        identifier: MessageIdentifier,
        botRepository: BotRepository = BotRepository.shared,
        appController: AppController = AppController.shared
    ) -> UIHostingController<some View> {
        UIHostingController(
            rootView: MessageView(identifier: identifier, bot: botRepository.current)
                .injectAppEnvironment(botRepository: botRepository, appController: appController)
        )
    }
}

struct MessageView: View {
    /// The Identifier or the Message it will show information for.
    ///
    /// This view will load the Identifier if not present, or use the Message (and save a database call) if it is.
    var identifierOrMessage: Either<MessageIdentifier, Message>

    @State
    private var message: Message?

    @State
    private var root: Message?

    @EnvironmentObject
    private var botRepository: BotRepository

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    @State
    private var showCompose = false

    @State
    private var isLoadingMessage = false

    @State
    private var isLoadingRoot = false

    init(identifier: MessageIdentifier, shouldOpenCompose: Bool = false, bot: Bot) {
        self.init(identifierOrMessage: .left(identifier), shouldOpenCompose: shouldOpenCompose, bot: bot)
    }

    init(message: Message, shouldOpenCompose: Bool = false, bot: Bot) {
        self.init(identifierOrMessage: .right(message), shouldOpenCompose: shouldOpenCompose, bot: bot)
    }

    init(identifierOrMessage: Either<MessageIdentifier, Message>, shouldOpenCompose: Bool, bot: Bot) {
        self.identifierOrMessage = identifierOrMessage
        switch identifierOrMessage {
        case .right(let message):
            self.message = message
        default:
            self.message = nil
        }
        self.showCompose = shouldOpenCompose
        self.dataSource = FeedStrategyMessageDataSource(
            strategy: RepliesStrategy(identifier: identifierOrMessage.id),
            bot: bot
        )
    }

    var identifierOrLoadedMessage: Either<MessageIdentifier, Message> {
        if let message = message {
            return .right(message)
        } else {
            return identifierOrMessage
        }
    }

    var rootIdentifier: Either<MessageIdentifier, Message>? {
        if let root = root {
            return .right(root)
        } else if let identifier = message?.content.post?.root {
            return .left(identifier)
        } else if let identifier = message?.content.vote?.vote.link {
            return .left(identifier)
        } else {
            return nil
        }
    }

    var body: some View {
        Group {
            if isLoadingMessage {
                LoadingView()
            } else {
                VStack(spacing: 0) {
                    ScrollView(.vertical) {
                        ZStack(alignment: .top) {
                            if isLoadingRoot {
                                LoadingCard(style: .compact)
                                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                    .opacity(0.7)
                            } else if let rootIdentifier = rootIdentifier {
                                ZStack {
                                    MessageButton(
                                        identifierOrMessage: rootIdentifier,
                                        style: .compact,
                                        shouldDisplayChain: false
                                    )
                                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
                                    .opacity(0.7)
                                }
                                .frame(height: 100, alignment: .top)
                            }
                            CompactMessageView(
                                identifierOrMessage: identifierOrLoadedMessage,
                                shouldTruncateIfNeeded: false,
                                didTapReply: {
                                    showCompose = true
                                }
                            )
                            .compositingGroup()
                            .shadow(color: .cardBorderBottom, radius: 0, x: 0, y: 4)
                            .shadow(
                                color: .cardShadowBottom,
                                radius: 10,
                                x: 0,
                                y: 4
                            )
                            .offset(y: rootIdentifier == nil ? 0 : 100)
                            .padding(
                                EdgeInsets(top: 0, leading: 0, bottom: rootIdentifier == nil ? 0 : 100, trailing: 0)
                            )
                        }
                        MessageStack(dataSource: dataSource, chained: true)
                            .placeholder(when: dataSource.isEmpty, alignment: .top) {
                                EmptyView()
                            }
                        Spacer(minLength: 15)
                    }
                }
            }
        }
        .background(Color.appBg)
        .navigationTitle(title)
        .onReceive(NotificationCenter.default.publisher(for: .didPublishPost)) { _ in
            Task {
                await reloadMessage()
                await dataSource.loadFromScratch()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .didPublishVote)) { notification in
            guard let identifier = notification.identifier else {
                return
            }
            if identifier == message?.key {
                Task {
                    await reloadMessage()
                    await dataSource.loadFromScratch()
                }
            } else if let cache = dataSource.cache, cache.contains(where: { $0.key == identifier }) {
                Task {
                    await dataSource.loadFromScratch()
                }
            }
        }
        .sheet(isPresented: $showCompose) {
            ComposeView(isPresenting: $showCompose, root: message)
        }
        .task {
            loadMessageIfNeeded()
            loadRootIfNeeded()
        }
    }

    private var title: String {
        switch identifierOrMessage {
        case .left:
            return Localized.Message.message.text
        case .right(let message):
            switch message.content.type {
            case .post:
                if message.content.post?.root != nil {
                    return Localized.Message.reply.text
                } else {
                    return Localized.Post.title.text
                }
            case .contact:
                return Localized.Message.contact.text
            case .vote:
                return Localized.Message.reaction.text
            default:
                return Localized.Message.message.text
            }
        }
    }

    private func loadMessageIfNeeded() {
        guard message == nil else {
            return
        }
        switch identifierOrMessage {
        case .left(let messageIdentifier):
            isLoadingMessage = true
            Task.detached {
                let bot = await botRepository.current
                do {
                    let result = try await bot.message(identifier: messageIdentifier)
                    await MainActor.run {
                        message = result
                        isLoadingMessage = false
                        loadRootIfNeeded()
                    }
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await MainActor.run {
                        message = nil
                        isLoadingMessage = false
                    }
                }
            }
        case .right(let message):
            self.message = message
        }
    }

    private func reloadMessage() async {
        let messageIdentifier = identifierOrMessage.id
        let bot = botRepository.current
        do {
            let result = try await bot.message(identifier: messageIdentifier)
            await MainActor.run {
                message = result
            }
        } catch {
            Log.optional(error)
            CrashReporting.shared.reportIfNeeded(error: error)
        }
    }

    private func loadRootIfNeeded() {
        guard root == nil else {
            return
        }
        guard let content = message?.content else {
            return
        }
        var rootIdentifier: MessageIdentifier?
        switch content.type {
        case .vote:
            rootIdentifier = content.vote?.vote.link
        case .post:
            rootIdentifier = content.post?.root
        default:
            rootIdentifier = nil
        }
        guard let rootIdentifier = rootIdentifier else {
            return
        }
        isLoadingRoot = true
        Task.detached {
            let bot = await botRepository.current
            do {
                let result = try await bot.message(identifier: rootIdentifier)
                await MainActor.run {
                    root = result
                    isLoadingRoot = false
                }
            } catch {
                Log.optional(error)
                CrashReporting.shared.reportIfNeeded(error: error)
                await MainActor.run {
                    root = nil
                    isLoadingRoot = false
                }
            }
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
        NavigationView {
            MessageView(message: message, bot: FakeBot())
                .injectAppEnvironment(botRepository: .fake)
        }
    }
}
