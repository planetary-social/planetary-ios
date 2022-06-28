//
//  CrashReportingServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
import Logger

/// This implementation of CrashReportingService starts the APIService
/// when a botLogHandler is set. So be sure to always set it.
class CrashReportingServiceAdapter: CrashReportingService {

    var apiService: APIService
    var logger: LogProtocol

    init(_ apiService: APIService, logger: LogProtocol = Log.shared, logsBuilder: LogsBuilder = DefaultLogsBuilder()) {
        self.apiService = apiService
        self.logger = logger
        self.apiService.onEventHandler = { (identity) -> Logs in
            return logsBuilder.build(logger: logger, identity: identity)
        }
        self.apiService.start()
    }

    func identify(identity: Identity) {
        apiService.identify(identity: identity)
    }

    func forget() {
        apiService.forget()
    }

    func record(_ message: String) {
        logger.debug(message)
        apiService.record(message)
    }

    func report(error: Error, metadata: [AnyHashable: Any]? = nil) {
        logger.error(error.localizedDescription)
        apiService.report(error: error, metadata: metadata)
    }
}
