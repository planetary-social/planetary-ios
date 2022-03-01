//
//  BotStatisticsService.swift
//  Planetary
//
//  Created by Matthew Lorentz on 2/23/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation
import Combine

protocol BotStatisticsService {
    func subscribe() async -> AnyPublisher<BotStatistics, Never>
}

actor BotStatisticsServiceAdaptor: BotStatisticsService {
            
    private var statisticsPublisher: AnyPublisher<BotStatistics, Never>?
    
    private var refreshInterval: TimeInterval
    
    private var bot: Bot
    
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
            .flatMap { (_: Date) -> AnyPublisher<BotStatistics, Never> in
                return Future<BotStatistics, Never> { promise in
                    self.bot.statistics(completion: { statistics in
                        promise(.success(statistics))
                    })
                }.eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
        
        return statisticsPublisher
    }

    
    init(bot: Bot, refreshInterval: TimeInterval = 1) {
        self.bot = bot
        self.refreshInterval = refreshInterval
    }
}
