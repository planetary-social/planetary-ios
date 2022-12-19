//
//  FeedStrategyMessageList.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger

class FeedStrategyMessageList: MessageList {
    let strategy: FeedStrategy
    let bot: Bot

    init(strategy: FeedStrategy, bot: Bot) {
        self.strategy = strategy
        self.bot = bot
    }

    @MainActor
    @Published
    var cache: [Message]?

    @Published
    var isLoadingMore = false

    @Published
    var isLoadingFromScratch = false

    private let pageSize = 50

    private var offset = 0

    private var noMoreMessages = false

    private var errorMessage: String?

    @MainActor
    func loadFromScratch() async {
        guard !isLoadingFromScratch else {
            return
        }
        isLoadingFromScratch = true
        do {
            let messages = try await bot.feed(strategy: strategy, limit: pageSize, offset: 0)
            await MainActor.run {
                print("LISTEN: Load from scratch")
                cache = messages
                offset = messages.count
                noMoreMessages = messages.count < pageSize
                isLoadingFromScratch = false
            }
        } catch {
            CrashReporting.shared.reportIfNeeded(error: error)
            Log.shared.optional(error)
            await MainActor.run {
                errorMessage = error.localizedDescription
                cache = []
                offset = 0
                noMoreMessages = true
                isLoadingFromScratch = false
            }
        }
    }

    @MainActor
    func loadMore() {
        guard !isLoadingMore, !noMoreMessages else {
            return
        }
        isLoadingMore = true
        Task {
            // let strategy = await feedStrategyStore.homeFeedStrategy
            // let bot = await botRepository.current
            do {
                let messages = try await bot.feed(strategy: strategy, limit: pageSize, offset: offset)
                await MainActor.run {
                    print("LISTEN: Load more")
                    cache?.append(contentsOf: messages)
                    offset += messages.count
                    noMoreMessages = messages.count < pageSize
                    isLoadingMore = false
                }
            } catch {
                CrashReporting.shared.reportIfNeeded(error: error)
                Log.shared.optional(error)
                await MainActor.run {
                    isLoadingMore = false
                }
            }
        }
    }
}
