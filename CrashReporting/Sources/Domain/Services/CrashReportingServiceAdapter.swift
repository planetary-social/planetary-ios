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

    init(_ apiService: APIService) {
        self.apiService = apiService
    }

    func identify(identity: Identity) {
        apiService.identify(identity: identity)
    }

    func forget() {
        apiService.forget()
    }

    func record(_ message: String) {
        Log.debug(message)
        apiService.record(message)
    }

    func report(error: Error, metadata: [AnyHashable: Any]? = nil) {
        Log.error(error.localizedDescription)
        apiService.report(error: error, metadata: metadata)
    }

}
