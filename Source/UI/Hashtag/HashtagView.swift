//
//  HashtagView.swift
//  Planetary
//
//  Created by Martin Dutra on 29/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Analytics
import CrashReporting
import Logger
import SwiftUI

@MainActor
struct HashtagView: View {
    
    var hashtag: Hashtag

    init(hashtag: Hashtag, bot: Bot) {
        self.hashtag = hashtag
        self.dataSource = FeedStrategyMessageDataSource(
            strategy: HashtagAlgorithm(hashtag: hashtag),
            bot: bot
        )
    }

    @ObservedObject
    private var dataSource: FeedStrategyMessageDataSource

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        MessageList(dataSource: dataSource)
            .placeholder(when: dataSource.isEmpty) {
                EmptyPostsView(description: Localized.Message.noPostsInHashtagDescription)
            }
            .background(Color.appBg)
            .navigationTitle(hashtag.string)
    }
}

struct HashtagView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HashtagView(
                hashtag: Hashtag(name: "technology"),
                bot: FakeBot.shared
            )
        }
        .injectAppEnvironment()
    }
}
