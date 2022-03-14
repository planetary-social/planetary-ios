//
//  File.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation

class MonitorServiceAdapter: MonitorService {

    var apiService: APIService

    init(apiService: APIService) {
        self.apiService = apiService
    }

    func identify(identity: Identity) {
        apiService.identify(identity: identity)
    }

    func forget() {
        apiService.forget()
    }

    func record(_ message: String) {
        apiService.record(message)
    }

    func report(error: Error, metadata: [AnyHashable: Any]? = nil) {
        apiService.report(error: error, metadata: metadata)
    }

}
