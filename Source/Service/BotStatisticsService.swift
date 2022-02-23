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
    func subscribe() async -> AnyPublisher<BotStatistics?, Never>
}

actor BotStatisticsServiceAdaptor: BotStatisticsService {
    
    static let shared = BotStatisticsServiceAdaptor(bot: GoBot.shared)
    
    private var statisticsPublisher: AnyPublisher<BotStatistics?, Never>
    
    func subscribe() async -> AnyPublisher<BotStatistics?, Never> {
        return statisticsPublisher
    }

    
    init(bot: Bot, refreshInterval: DispatchTimeInterval = .seconds(1)) {
        statisticsPublisher = PassthroughSubject<BotStatistics?, Never>().eraseToAnyPublisher()
    }
}
