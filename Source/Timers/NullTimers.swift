//
//  NullTimers.swift
//  Planetary
//
//  Created by Martin Dutra on 5/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// A null implementation of the TimersService protocol suitable
/// for use with unit or API test targets.

typealias Timers = NullTimers

class NullTimers: TimersService {
    
    static var shared: TimersService = NullTimers()
    
    var syncTimer = RepeatingTimer(interval: 60, completion: { })
    var refreshTimer = RepeatingTimer(interval: 17, completion: {  })
    
}
