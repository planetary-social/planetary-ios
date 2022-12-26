//
//  FeedStrategyMessageDataSource.swift
//  Planetary
//
//  Created by Martin Dutra on 19/12/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import CrashReporting
import Foundation
import Logger

class FeedStrategyMessageDataSource: MessageDataSource {
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

    @Published
    var errorMessage: String?

    /// The number of loaded pages
    @Published
    var pages = 0

    @MainActor
    var isEmpty: Bool {
        if let cache = cache {
            return cache.count == 0
        }
        return false
    }

    /// The size of each page
    private let pageSize = 50

    /// The number of messages loaded
    private var offset = 0

    /// If true, we know there are no more pages to be loaded
    private var noMoreMessages = false

    @MainActor
    func loadFromScratch() async {
        guard !isLoadingFromScratch else {
            return
        }
        isLoadingFromScratch = true
        do {
            let messages = try await bot.feed(strategy: strategy, limit: pageSize, offset: 0)
            await MainActor.run {
                cache = messages
                offset = messages.count
                noMoreMessages = messages.count < pageSize
                isLoadingFromScratch = false
                pages = 1
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
                pages = 0
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
                    cache?.append(contentsOf: messages)
                    offset += messages.count
                    noMoreMessages = messages.count < pageSize
                    isLoadingMore = false
                    pages += 1
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
