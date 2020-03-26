//
//  NullLog.swift
//  FBTT
//
//  Created by Christoph on 7/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation

typealias Log = NullLog

/// A null implementation of the LogService protocol suitable
/// for use with unit or API test targets.
class NullLog: LogService {

    static func configure() { }
    
    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        guard let _ = error else { return false }
        return true
    }

    static func info(_ string: String) {}

    static func unexpected(_ reason: LogReason, _ detail: String? = nil) {}

    static func fatal(_ reason: LogReason, _ detail: String? = nil) {}
}
