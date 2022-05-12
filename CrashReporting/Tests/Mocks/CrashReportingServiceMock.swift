//
//  MonitorServiceMock.swift
//  
//
//  Created by Martin Dutra on 9/12/21.
//

import Foundation
@testable import CrashReporting

class CrashReportingServiceMock: CrashReportingService {
    var botLogHandler: (() -> String?)?
    var identified = false
    var crashed = false
    var forgot = false
    var recorded = false

    func identify(identity: Identity) {
        identified = true
    }

    func forget() {
        forgot = true
    }

    func record(_ message: String) {
        recorded = true
    }

    func report(error: Error, metadata: [AnyHashable: Any]?) {
        crashed = true
    }
}
