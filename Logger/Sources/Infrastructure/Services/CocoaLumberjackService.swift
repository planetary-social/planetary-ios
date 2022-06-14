//
//  CocoaLumberjackService.swift
//  
//
//  Created by Martin Dutra on 10/2/22.
//

import Foundation
import CocoaLumberjackSwift

class CocoaLumberjackService: FileLoggerService {

    private var fileLogger: DDFileLogger

    var fileUrls: [URL] {
        fileLogger.logFileManager.sortedLogFilePaths.map { URL(fileURLWithPath: $0) }
    }

    init() {
        fileLogger = DDFileLogger()
        fileLogger.rollingFrequency = 60 * 60 * 24 // 24 hours
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        DDLog.add(fileLogger)
    }

    func debug(_ string: String) {
        DDLogDebug(string, asynchronous: false)
    }

    func info(_ string: String) {
        DDLogInfo(string, asynchronous: false)
    }

    func error(_ string: String) {
        DDLogError(string, asynchronous: false)
    }
}
