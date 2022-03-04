//
//  BotStatisticsService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Combine

/// A service class that will publish `BotStatistics` regularly when subscribed to.
protocol BotStatisticsService {
    func subscribe() async -> AnyPublisher<BotStatistics, Never>
}

/// A concrete implementation of `BotStatisticsService` that queries any `Bot`. This service polls the bot for new
/// statistics when subscribed to, and stops publishing when there are no more subscribers as an optimization.
actor BotStatisticsServiceAdaptor: BotStatisticsService {
            
    private var statisticsPublisher: AnyPublisher<BotStatistics, Never>?
    
    private var refreshInterval: TimeInterval
    
    private var bot: Bot
    
    init(bot: Bot, refreshInterval: TimeInterval = 1) {
        self.bot = bot
        self.refreshInterval = refreshInterval
    }
    
    /// Call this function to get an observable stream of `BotStatistics`, published regularly.
    func subscribe() async -> AnyPublisher<BotStatistics, Never> {
        if let statisticsPublisher = statisticsPublisher {
            return statisticsPublisher
        }
        
        let statisticsPublisher: AnyPublisher<BotStatistics, Never> = Timer.publish(
            every: refreshInterval,
            on: .main,
            in: .default
        )
            .autoconnect()
            // Fire timer once immediately
            .merge(with: Just(Date()))
            .asyncFlatMap(maxPublishers: .max(1)) { _ in
                await self.bot.statistics()
            }
            .eraseToAnyPublisher()
        
        return statisticsPublisher
    }
}
