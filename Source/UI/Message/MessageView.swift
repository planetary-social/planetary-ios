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

    @EnvironmentObject
    private var botRepository: BotRepository

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    init(identifier: MessageIdentifier, bot: Bot) {
        self.init(identifierOrMessage: .left(identifier), bot: bot)
    }

    init(message: Message, bot: Bot) {
        self.init(identifierOrMessage: .right(message), bot: bot)
    }

    init(identifierOrMessage: Either<MessageIdentifier, Message>, bot: Bot) {
        self.identifierOrMessage = identifierOrMessage
        self.dataSource = FeedStrategyMessageDataSource(
            strategy: RepliesStrategy(identifier: identifierOrMessage.id),
            bot: bot
        )
    }

    var body: some View {
        Group {
            if let message = message {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 0) {
                        MessageHeaderView(message: message)
                        Divider().overlay(Color.cardDivider).shadow(color: .cardDividerShadow, radius: 0, x: 0, y: 1)
                        if let contact = message.content.contact {
                            IdentityCard(identity: contact.contact, style: .compact)
                        } else if let post = message.content.post {
                            CompactPostView(identifier: message.id, post: post, lineLimit: nil)
                        } else if let vote = message.content.vote {
                            CompactVoteView(identifier: message.id, vote: vote.vote)
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
                    .shadow(
                        color: .cardShadowBottom,
                        radius: 10,
                        x: 0,
                        y: 4
                    )
                    MessageStack(dataSource: dataSource, chained: true)
                        .placeholder(when: dataSource.isEmpty, alignment: .top) {
                            EmptyView()
                        }
                    Spacer(minLength: 15)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color.appBg)
        .navigationTitle(Localized.Post.one.text)
        .task {
            loadMessageIfNeeded()
        }
    }

    private func loadMessageIfNeeded() {
        guard message == nil else {
            return
        }
        switch identifierOrMessage {
        case .left(let messageIdentifier):
            Task.detached {
                let bot = await botRepository.current
                do {
                    let result = try await bot.message(identifier: messageIdentifier)
                    await MainActor.run {
                        message = result
                    }
                } catch {
                    Log.optional(error)
                    CrashReporting.shared.reportIfNeeded(error: error)
                    await MainActor.run {
                        message = nil
                    }
                }
            }
        case .right(let message):
            self.message = message
        }
    }
}

struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        MessageView(identifier: .null, bot: FakeBot())
            .injectAppEnvironment(botRepository: .fake)
    }
}
