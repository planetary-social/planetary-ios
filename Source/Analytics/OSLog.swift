//
//  OSLog.swift
//  FBTT
//
//  Created by Christoph on 7/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import os.log

typealias Log = OSLog

/// LogService implementation built on top of the
/// os.log framework.
/// https://developer.apple.com/documentation/os/logging
class OSLog: LogService {

    // Convenience function to log an optional Error.
    // If the error is nil nothing is done, which makes
    // this useful for debug code.
    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        guard let error = error else { return false }
        let string = "LOG:ERROR:\(detail ?? "") \(error)"
        os_log("%@", type: OSLogType.error, string)
        Analytics.log(.error, string)
        return true
    }

    static func info(_ string: String) {
        Analytics.log(.info, string)
        let message = "LOG:INFO: \(string)"
        os_log("%@", type: OSLogType.info, message)
    }

    static func unexpected(_ reason: LogReason, _ detail: String? = nil) {
        let string = "\(reason.rawValue) \(detail ?? "")"
        Analytics.log(.unexpected, string)
        let message = "LOG:UNEXPECTED:\(string)"
        os_log("%@", type: OSLogType.error, message)
    }

    static func fatal(_ reason: LogReason, _ detail: String? = nil) {
        let string = "\(reason.rawValue) \(detail ?? "")"
        Analytics.log(.fatal, string)
        let message = "LOG:FATAL:\(string)"
        os_log("%@", type: OSLogType.fault, message)
    }
}
