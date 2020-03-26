//
//  Log.swift
//  FBTT
//
//  Created by Christoph on 3/21/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

enum LogReason: String {
    case apiError
    case botError
    case missingValue
    case incorrectValue
}

/// A protocol that defines a stateless log API for use across
/// all layers of an application.  Clients are encouraged to
/// define `Log` to point to a specific implementation, like
/// `typealias Log = OSLog`.  This allows the implementation
/// to be changed on a per target level based on needs.
protocol LogService {
    static func configure()
    static func optional(_ error: Error?, _ detail: String?) -> Bool
    static func info(_ string: String)
    static func unexpected(_ reason: LogReason, _ detail: String?)
    static func fatal(_ reason: LogReason, _ detail: String?)
}
