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

    private var strategy: FeedStrategy {
        HashtagAlgorithm(hashtag: hashtag)
    }

    @State
    var messages: [Message]?

    @State
    private var isLoadingMoreMessages = false

    @State
    private var offset = 0

    @State
    private var noMoreMessages = false

    @EnvironmentObject
    private var botRepository: BotRepository

    @EnvironmentObject
    private var appController: AppController

    var body: some View {
        Group {
            if let messages = messages {
                ScrollView(.vertical, showsIndicators: false) {
                    ZStack {
                        LazyVStack {
                            if messages.isEmpty {
                                EmptyPostsView(description: Localized.Message.noPostsInHashtagDescription)
                            } else {
                                ForEach(messages) { message in
                                    Button {
                                        appController.open(identifier: message.id)
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
                        }
                        .frame(maxWidth: 500)
                        .padding(EdgeInsets(top: 0, leading: 0, bottom: 15, trailing: 0))
                        if isLoadingMoreMessages, !noMoreMessages {
                            HStack {
                                ProgressView().frame(maxWidth: .infinity, alignment: .center).padding()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                LoadingView()
            }
        }
        .task {
            await loadFromScratch()
        }
        .refreshable {
            await loadFromScratch()
        }
        .background(Color.appBg)
        .navigationTitle(hashtag.string)
    }

    func loadFromScratch() async {
        let bot = botRepository.current
        let pageSize = 50
        do {
            let newMessages = try await bot.feed(strategy: strategy, limit: pageSize, offset: 0)
            await MainActor.run {
                messages = newMessages
                offset = newMessages.count
                noMoreMessages = newMessages.count < pageSize
            }
        } catch {
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.shared.optional(error)
            await MainActor.run {
                messages = []
                offset = 0
                noMoreMessages = true
            }
        }
    }

    func loadMore() {
        guard !isLoadingMoreMessages, !noMoreMessages else {
            return
        }
        isLoadingMoreMessages = true
        Task.detached {
            let bot = await botRepository.current
            let pageSize = 50
            do {
                let newMessages = try await bot.feed(strategy: strategy, limit: pageSize, offset: offset)
                await MainActor.run {
                    messages?.append(contentsOf: newMessages)
                    offset += newMessages.count
                    noMoreMessages = newMessages.count < pageSize
                    isLoadingMoreMessages = false
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    isLoadingMoreMessages = false
                }
            }
        }
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
