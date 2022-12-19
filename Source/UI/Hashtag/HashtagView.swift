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

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        MessageListView(
            dataSource: FeedStrategyMessageList(
                strategy: HashtagAlgorithm(hashtag: hashtag),
                bot: botRepository.current
            )
        )
        .background(Color.appBg)
        .navigationTitle(hashtag.string)
    }
}

struct HashtagView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HashtagView(hashtag: Hashtag(name: "technology"))
        }
        .environmentObject(BotRepository.fake)
        .environmentObject(AppController.shared)
    }
}
