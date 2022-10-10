//
//  MessageListController.swift
//  Planetary
//
//  Created by Matthew Lorentz on 10/10/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

class MessageListController: MessageListViewModel {
    
    @MainActor @Published var cache = [Message]()
    
    @Published var isLoading = false
    
    private var bot: Bot
    
    private var dataSourceInitTask: Task<PaginatedMessageDataProxy, Error>
    private var pageSize = 100
    
    init(bot: Bot) {
        self.bot = bot
        self.dataSourceInitTask = Task.detached {
            return try await bot.recent()
        }
    }
    
    private func dataSource() async throws -> PaginatedMessageDataProxy {
        try await dataSourceInitTask.value
    }
    
    @MainActor func loadMore() {
        
        isLoading = true
        Task {
            defer { self.isLoading = false }
            // TODO: handle this error
            let dataSource = try await self.dataSource()
            
            guard dataSource.count > 0 else {
                return
            }
            let upperFetchBound = dataSource.count - 1
            
            let newLastIndex = min(self.cache.count - 1 + self.pageSize, upperFetchBound)
            guard newLastIndex >= self.cache.count else {
                // we are at the end of the list
                return
            }
            
            dataSource.prefetchUpTo(index: newLastIndex)
            
            for i in self.cache.count...newLastIndex {
                self.cache.append(await dataSource.messageBy(index: i))
            }
        }
    }
}
