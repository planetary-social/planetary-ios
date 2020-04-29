//
//  Timers.swift
//  FBTT
//
//  Created by Christoph on 5/16/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Typically apps end up with a number of timers sprinkled throughout
/// the project.  This struct is intended to capture those timers in a
/// single accessible place to better understand the number and scope.
struct Timers {
    static let syncTimer = RepeatingTimer(interval: 60, completion: { AppController.shared.pokeSync() })
    static let refreshTimer = RepeatingTimer(interval: 15, completion: { AppController.shared.pokeRefresh() })
    static let pokeTimers = [syncTimer, refreshTimer]
}
