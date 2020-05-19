//
//  AppTimers.swift
//  Planetary
//
//  Created by Martin Dutra on 5/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias Timers = AppTimers

class AppTimers: TimersService {
    
    static var shared: TimersService = AppTimers()
    
    var syncTimer = RepeatingTimer(interval: 60, completion: { AppController.shared.pokeSync() })
    var refreshTimer = RepeatingTimer(interval: 17, completion: { AppController.shared.pokeRefresh() })
    
}
