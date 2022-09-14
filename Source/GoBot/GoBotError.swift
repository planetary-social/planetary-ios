//
//  GoBotError.swift
//  Planetary
//
//  Created by Martin Dutra on 4/7/20.
//  Copyright © 2020 Verse Communications Inc. All rights reserved.
//

import Foundation

enum GoBotError: Error {
    case alreadyStarted
    case duringProcessing(String, Error)
    case unexpectedFault(String)
    case deadlock
}
