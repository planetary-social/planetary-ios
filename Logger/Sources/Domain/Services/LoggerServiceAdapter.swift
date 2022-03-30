//
//  LoggerServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 10/2/22.
//

import Foundation
import os.log

/// The LoggerServiceAdapter class can be used to output logs to files in the device's filesystem
/// and to the Console (in real-time) when debugging
///
/// It implements LoggerService so it is meant to be used by Log as a plug-in that actually outputs to logs somewhere.
class LoggerServiceAdapter: LoggerService {

    var fileLoggerService: FileLoggerService

    init(fileLoggerService: FileLoggerService) {
        self.fileLoggerService = fileLoggerService
    }

    var fileUrls: [URL] {
        fileLoggerService.fileUrls
    }

    func debug(_ string: String) {
        let message = "LOG:DEBUG: \(string)"
        fileLoggerService.debug(message)
        os_log("%@", type: OSLogType.debug, message)
    }

    func info(_ string: String) {
        let message = "LOG:INFO: \(string)"
        os_log("%@", type: OSLogType.info, message)
        fileLoggerService.info(message)
    }

    func optional(_ error: Error?, _ detail: String?) -> Bool {
        guard let error = error else {
            return false
        }
        let message = "LOG:ERROR:\(detail ?? "") \(error)"
        os_log("%@", type: OSLogType.error, message)
        fileLoggerService.error(message)
        return true
    }

    func unexpected(_ reason: String, _ detail: String?) {
        let message = "LOG:UNEXPECTED:\(reason) \(detail ?? "")"
        os_log("%@", type: OSLogType.error, message)
        fileLoggerService.error(message)
    }

    func fatal(_ reason: String, _ detail: String?) {
        let message = "LOG:FATAL:\(reason) \(detail ?? "")"
        os_log("%@", type: OSLogType.fault, message)
        fileLoggerService.error(message)
    }
}
