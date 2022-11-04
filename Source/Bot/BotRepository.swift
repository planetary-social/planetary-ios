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
    var current: Bot {
        Bots.current
    }
}
