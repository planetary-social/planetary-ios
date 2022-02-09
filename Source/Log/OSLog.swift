//
//  OSLog.swift
//  FBTT
//
//  Created by Christoph on 7/25/19.
//  Copyright © 2019 Verse Communications Inc. All rights reserved.
//

import Foundation
import os.log
import CocoaLumberjack

typealias Log = OSLog

/// LogService implementation built on top of the
/// os.log framework.
/// https://developer.apple.com/documentation/os/logging
class OSLog: LogService {
    
    static func configure() {
        os_log("%@", self.fileLogger.debugDescription)
    }
    
    private static let fileLogger: DDFileLogger = {
        let fileLogger = DDFileLogger() // File Logger
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
        return fileLogger
    }()
    
    static var fileUrls: [URL] {
        return self.fileLogger.logFileManager.sortedLogFilePaths.map { URL(fileURLWithPath: $0) }
    }

    // Convenience function to log an optional Error.
    // If the error is nil nothing is done, which makes
    // this useful for debug code.
    @discardableResult
    static func optional(_ error: Error?, _ detail: String? = nil) -> Bool {
        guard let error = error else { return false }
        let string = "LOG:ERROR:\(detail ?? "") \(error)"
        os_log("%@", type: OSLogType.error, string)
        DDLogError(string)
        return true
    }
    
    static func error(_ message: String) {
        let string = "LOG:ERROR:\(message)"
        os_log("%@", type: OSLogType.error, string)
        DDLogError(string)
    }

    static func info(_ string: String) {
        DDLogInfo(string)
        let message = "LOG:INFO: \(string)"
        os_log("%@", type: OSLogType.info, message)
    }

    static func unexpected(_ reason: LogReason, _ detail: String? = nil) {
        let string = "\(reason.rawValue) \(detail ?? "")"
        DDLogError(string)
        let message = "LOG:UNEXPECTED:\(string)"
        os_log("%@", type: OSLogType.error, message)
    }

    static func fatal(_ reason: LogReason, _ detail: String? = nil) {
        let string = "\(reason.rawValue) \(detail ?? "")"
        DDLogError(string)
        let message = "LOG:FATAL:\(string)"
        os_log("%@", type: OSLogType.fault, message)
    }

    static func debug(_ string: String) {
        DDLogDebug(string)
        let message = "LOG:DEBUG: \(string)"
        os_log("%@", type: OSLogType.debug, message)
    }
}
