//
//  Date+millisecs.swift
//  FBTT
//
// these are usefull to work with javascript timestamps
// i'd love for these to be ints but dominic enforced monotonics at one point so there are messages with t1 and t1+0.01
//
//  Created by Henry Bubert on 24.04.19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

extension Date {
    var millisecondsSince1970: Double {
        self.timeIntervalSince1970 * 1_000.0
    }
    
    init(milliseconds: Double) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
    }
}
