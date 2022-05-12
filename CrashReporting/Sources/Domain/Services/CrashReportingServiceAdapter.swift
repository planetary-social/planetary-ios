//
//  CrashReportingServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
import Logger

class CrashReportingServiceAdapter: CrashReportingService {

    var apiService: APIService
    var logger: LogProtocol
    var botLogHandler: (() -> String?)?

    init(_ apiService: APIService, logger: LogProtocol = Log.shared) {
        self.apiService = apiService
        self.logger = logger
        self.apiService.onEventHandler = { [weak self] () -> Logs in
            var appLog: String?
            if let logUrls = logger.fileUrls.first {
                do {
                    let data = try Data(contentsOf: logUrls)
                    appLog = String(data: data, encoding: .utf8)
                } catch {
                    logger.optional(error, nil)
                }
            }
            let botLog = self?.botLogHandler?()
            return Logs(appLog: appLog, botLog: botLog)
        }
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
