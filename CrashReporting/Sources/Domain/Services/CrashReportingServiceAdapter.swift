//
//  CrashReportingServiceAdapter.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
import Logger

class CrashReportingServiceAdapter: CrashReportingService {

    var api: APIService

    init(api: APIService) {
        self.api = api
    }

    func identify(identity: Identity) {
        api.identify(identity: identity)
    }

    func forget() {
        api.forget()
    }

    func record(_ message: String) {
        Log.debug(message)
        api.record(message)
    }

    func report(error: Error, metadata: [AnyHashable: Any]? = nil) {
        Log.error(error.localizedDescription)
        api.report(error: error, metadata: metadata)
    }

}
