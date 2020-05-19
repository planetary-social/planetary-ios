//
//  TimersService.swift
//  Planetary
//
//  Created by Martin Dutra on 5/15/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

/// Typically apps end up with a number of timers sprinkled throughout
/// the project.  This struct is intended to capture those timers in a
/// single accessible place to better understand the number and scope.

protocol TimersService {

    static var shared: TimersService  { get }

    var syncTimer: RepeatingTimer { get }
    var refreshTimer: RepeatingTimer { get }
    
}

extension TimersService {
    
    var pokeTimers: [RepeatingTimer] {
        return [syncTimer, refreshTimer]
    }
    
}
