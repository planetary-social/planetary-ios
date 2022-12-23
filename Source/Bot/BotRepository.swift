//
//  BotRepository.swift
//  Planetary
//
//  Created by Martin Dutra on 4/11/22.
//  Copyright © 2022 Verse Communications Inc. All rights reserved.
//

import Foundation

final class BotRepository: ObservableObject, Sendable {
    static let shared = BotRepository()
    static let fake = BotRepository(fake: true)

    private let fake: Bool

    private init(fake: Bool = false) {
        self.fake = fake
    }

    var current: Bot {
        if fake {
            return Bots.fake
        }
        return Bots.current
    }
}
