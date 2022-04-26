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

    init(_ apiService: APIService, logger: LogProtocol = Log.shared) {
        self.apiService = apiService
        self.logger = logger
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

    func report(error: Error, metadata: [AnyHashable: Any]? = nil, botLog: String?) {
        logger.error(error.localizedDescription)
        var appLog: String?
        if let logUrls = logger.fileUrls.first {
            do {
                let data = try Data(contentsOf: logUrls)
                appLog = String(data: data, encoding: .utf8)
            } catch {
                logger.optional(error, nil)
            }
        }
        apiService.report(error: error, metadata: metadata, appLog: appLog, botLog: botLog)
    }
}
